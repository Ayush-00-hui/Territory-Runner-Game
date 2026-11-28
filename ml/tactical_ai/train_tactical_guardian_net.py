#!/usr/bin/env python3
"""
Tactical Guardian & Dynamic Incursion Deep Neural Network (PyTorch CUDA)
======================================================================
Trains a deep multi-task neural network on the NVIDIA GeForce RTX 5070 GPU.

Multi-Task Objectives:
1. Incursion Pacing & Sprint Duration:
   Predicts optimal sprint velocity target (m/s) and max sustainable duration (sec)
   under current elevation grade, fatigue accumulation, and athlete aerobic capacity.
2. Procedural Loot Crate Spawn Optimizer:
   Evaluates path detour cost and generates optimal spawn distance delta (m)
   for balanced in-run rewards.
3. Sector Guardian Ghost Pacing Quantiles (P10, P50, P90):
   Predicts adaptive ghost runner pacing multipliers across terrain slopes.

Exports:
- assets/models/tactical_guardian_weights.json (pure Dart inference)
- assets/models/tactical_guardian_meta.json (SHA-256 integrity hash + architecture metadata)
"""

import os
import sys
import json
import time
import hashlib
import math
import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import TensorDataset, DataLoader

# Ensure output directories exist
os.makedirs("assets/models", exist_ok=True)
os.makedirs("ml/reports", exist_ok=True)

# Set random seeds for reproducibility
SEED = 42
torch.manual_seed(SEED)
np.random.seed(SEED)
if torch.cuda.is_available():
    torch.cuda.manual_seed_all(SEED)

device = torch.device("cuda:0" if torch.cuda.is_available() else "cpu")
print(f"[ML-INIT] Utilizing Device: {device} ({torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'CPU'})")
if torch.cuda.is_available():
    print(f"[ML-INIT] Initial Allocated VRAM: {torch.cuda.memory_allocated(0)/(1024**2):.2f} MB")
    print(f"[ML-INIT] Total Device Memory: {torch.cuda.get_device_properties(0).total_memory/(1024**2):.2f} MB")

# ==============================================================================
# 1. SYNTHETIC & PHYSIOLOGICAL DATASET GENERATION
# ==============================================================================
# 100,000 synthetic athletic telemetry samples with physics-based constraints
NUM_SAMPLES = 100000

print(f"[DATASET] Synthesizing {NUM_SAMPLES:,} athletic telemetry points for multi-task training...")

# Features:
# 0: speed_mps (1.5 to 6.5 m/s, ~5.4 to 23.4 km/h)
# 1: grade_pct (-0.25 to +0.25, -25% to +25% incline)
# 2: cumulative_fatigue (0.0 fresh to 1.0 exhausted)
# 3: heading_change_rate_deg_s (0 to 45 deg/s)
# 4: athlete_experience_level (0 beginner, 1 intermediate, 2 elite)
# 5: cadence_spm (140 to 210 spm)
# 6: altitude_m (0 to 2500m)
# 7: local_territory_density (0.0 to 1.0)

speed_mps = np.random.uniform(2.0, 5.5, NUM_SAMPLES).astype(np.float32)
grade_pct = np.random.uniform(-0.15, 0.15, NUM_SAMPLES).astype(np.float32)
fatigue = np.random.uniform(0.0, 0.95, NUM_SAMPLES).astype(np.float32)
heading_rate = np.random.exponential(5.0, NUM_SAMPLES).clip(0, 45).astype(np.float32)
experience = np.random.choice([0.0, 1.0, 2.0], size=NUM_SAMPLES, p=[0.3, 0.5, 0.2]).astype(np.float32)
cadence = np.random.uniform(150.0, 195.0, NUM_SAMPLES).astype(np.float32)
altitude = np.random.uniform(50.0, 1500.0, NUM_SAMPLES).astype(np.float32)
density = np.random.uniform(0.0, 1.0, NUM_SAMPLES).astype(np.float32)

X = np.stack([
    speed_mps, grade_pct, fatigue, heading_rate,
    experience, cadence, altitude, density
], axis=1)

# Normalization constants (saved in metadata for inference parity)
X_mean = X.mean(axis=0)
X_std = X.std(axis=0) + 1e-6
X_norm = (X - X_mean) / X_std

# Physics-based Ground Truth:
# 1. Incursion Sprint Velocity (m/s):
# Base sprint is 1.15x to 1.35x current speed, penalized by uphill grade and fatigue, boosted by experience
sprint_boost = 1.25 + 0.10 * (experience / 2.0) - 0.25 * fatigue - 0.8 * np.maximum(grade_pct, 0.0)
target_sprint_mps = (speed_mps * np.clip(sprint_boost, 1.05, 1.45)).clip(2.5, 7.5)

# 2. Incursion Max Duration (sec):
# Fresh runners can sprint 60-90s; fatigued or uphill drops to 30-45s
target_duration_s = (75.0 + 20.0 * experience - 35.0 * fatigue - 60.0 * np.maximum(grade_pct, 0.0)).clip(25.0, 120.0)

# 3. Loot Crate Optimal Detour (m):
# Average runner enjoys a 150m to 400m detour; fatigued runners prefer closer crates (150-250m)
target_crate_distance_m = (280.0 + 80.0 * (1.0 - fatigue) - 100.0 * np.abs(grade_pct) + 40.0 * density).clip(120.0, 450.0)

# 4. Sector Guardian Ghost Pacing Multipliers [P10, P50, P90]:
# Elite sector guardians run faster downhill, maintain pace on flats, surge strategically
guardian_p50 = (1.05 + 0.08 * (experience / 2.0) - 0.5 * grade_pct - 0.1 * fatigue).clip(0.85, 1.35)
guardian_p10 = (guardian_p50 - 0.08).clip(0.75, 1.25)
guardian_p90 = (guardian_p50 + 0.08).clip(0.95, 1.45)

# Combined Targets (6 outputs):
# [sprint_mps, duration_s, crate_distance_m, guardian_p10, guardian_p50, guardian_p90]
Y = np.stack([
    target_sprint_mps, target_duration_s, target_crate_distance_m,
    guardian_p10, guardian_p50, guardian_p90
], axis=1)

Y_mean = Y.mean(axis=0)
Y_std = Y.std(axis=0) + 1e-6
Y_norm = (Y - Y_mean) / Y_std

# Convert to PyTorch Tensors
X_tensor = torch.tensor(X_norm, dtype=torch.float32)
Y_tensor = torch.tensor(Y_norm, dtype=torch.float32)

dataset = TensorDataset(X_tensor, Y_tensor)
train_size = int(0.85 * NUM_SAMPLES)
val_size = NUM_SAMPLES - train_size
train_dataset, val_dataset = torch.utils.data.random_split(dataset, [train_size, val_size])

train_loader = DataLoader(train_dataset, batch_size=512, shuffle=True, pin_memory=True if torch.cuda.is_available() else False)
val_loader = DataLoader(val_dataset, batch_size=1024, shuffle=False)

print(f"[DATASET] Train set: {train_size:,} | Validation set: {val_size:,} | Batch Size: 512")

# ==============================================================================
# 2. DEEP NEURAL NETWORK ARCHITECTURE
# ==============================================================================
class TacticalGuardianNet(nn.Module):
    """
    Multi-Task Deep Neural Network with residual skip connections and layer normalization.
    Optimized for GPU execution and ultra-fast mobile forward passes.
    """
    def __init__(self, in_features=8, hidden_dim=128, out_features=6):
        super(TacticalGuardianNet, self).__init__()
        
        # Shared Feature Encoder
        self.encoder = nn.Sequential(
            nn.Linear(in_features, hidden_dim),
            nn.LayerNorm(hidden_dim),
            nn.LeakyReLU(0.1),
            nn.Linear(hidden_dim, hidden_dim),
            nn.LayerNorm(hidden_dim),
            nn.LeakyReLU(0.1),
        )
        
        # Residual Highway Block
        self.res_fc1 = nn.Linear(hidden_dim, hidden_dim)
        self.res_ln1 = nn.LayerNorm(hidden_dim)
        self.res_act = nn.LeakyReLU(0.1)
        self.res_fc2 = nn.Linear(hidden_dim, hidden_dim)
        self.res_ln2 = nn.LayerNorm(hidden_dim)
        
        # Multi-Task Task Heads
        # Head 1: Incursion Pacing & Duration [sprint_mps, duration_s]
        self.head_incursion = nn.Sequential(
            nn.Linear(hidden_dim, 64),
            nn.LeakyReLU(0.1),
            nn.Linear(64, 2)
        )
        
        # Head 2: Crate Distance [crate_distance_m]
        self.head_crate = nn.Sequential(
            nn.Linear(hidden_dim, 32),
            nn.LeakyReLU(0.1),
            nn.Linear(32, 1)
        )
        
        # Head 3: Sector Guardian Ghost Quantiles [P10, P50, P90]
        self.head_guardian = nn.Sequential(
            nn.Linear(hidden_dim, 64),
            nn.LeakyReLU(0.1),
            nn.Linear(64, 3)
        )

    def forward(self, x):
        h = self.encoder(x)
        # Residual connection
        res = self.res_act(self.res_ln1(self.res_fc1(h)))
        res = self.res_ln2(self.res_fc2(res))
        h = h + res
        
        out_inc = self.head_incursion(h)
        out_crate = self.head_crate(h)
        out_guard = self.head_guardian(h)
        
        return torch.cat([out_inc, out_crate, out_guard], dim=-1)

model = TacticalGuardianNet().to(device)
print(model)

total_params = sum(p.numel() for p in model.parameters())
print(f"[MODEL] Total Trainable Parameters: {total_params:,}")

# ==============================================================================
# 3. GPU TRAINING LOOP (100 EPOCHS WITH COSINE SCHEDULER)
# ==============================================================================
EPOCHS = 100
optimizer = optim.AdamW(model.parameters(), lr=1e-3, weight_decay=1e-4)
scheduler = optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=EPOCHS, eta_min=1e-5)
criterion = nn.SmoothL1Loss()

print(f"\n[TRAIN-START] Starting 100 epochs on {torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'CPU'}...")
t_start = time.time()

best_val_loss = float("inf")
train_losses = []
val_losses = []

for epoch in range(1, EPOCHS + 1):
    model.train()
    total_train_loss = 0.0
    for batch_x, batch_y in train_loader:
        batch_x, batch_y = batch_x.to(device), batch_y.to(device)
        
        optimizer.zero_grad()
        preds = model(batch_x)
        loss = criterion(preds, batch_y)
        loss.backward()
        optimizer.step()
        
        total_train_loss += loss.item() * batch_x.size(0)
        
    avg_train_loss = total_train_loss / train_size
    train_losses.append(avg_train_loss)
    scheduler.step()
    
    # Validation Phase
    model.eval()
    total_val_loss = 0.0
    with torch.no_grad():
        for batch_x, batch_y in val_loader:
            batch_x, batch_y = batch_x.to(device), batch_y.to(device)
            preds = model(batch_x)
            loss = criterion(preds, batch_y)
            total_val_loss += loss.item() * batch_x.size(0)
            
    avg_val_loss = total_val_loss / val_size
    val_losses.append(avg_val_loss)
    
    if avg_val_loss < best_val_loss:
        best_val_loss = avg_val_loss
        
    if epoch % 10 == 0 or epoch == 1 or epoch == EPOCHS:
        gpu_mem = torch.cuda.memory_allocated(0)/(1024**2) if torch.cuda.is_available() else 0.0
        print(f"  Epoch [{epoch:3d}/{EPOCHS}] - Train Loss: {avg_train_loss:.5f} | Val Loss: {avg_val_loss:.5f} | VRAM: {gpu_mem:.1f} MB | LR: {scheduler.get_last_lr()[0]:.6f}")

t_end = time.time()
print(f"\n[TRAIN-FINISH] Training completed in {t_end - t_start:.2f}s | Best Val Loss: {best_val_loss:.5f}")

# ==============================================================================
# 4. EVALUATION & ACCURACY METRICS
# ==============================================================================
model.eval()
with torch.no_grad():
    val_preds_all = []
    val_targets_all = []
    for batch_x, batch_y in val_loader:
        batch_x = batch_x.to(device)
        preds = model(batch_x).cpu().numpy()
        val_preds_all.append(preds)
        val_targets_all.append(batch_y.numpy())
        
val_preds = np.concatenate(val_preds_all, axis=0) * Y_std + Y_mean
val_targets = np.concatenate(val_targets_all, axis=0) * Y_std + Y_mean

# Calculate MAE for each output target
target_names = [
    "Sprint Pace Target (m/s)",
    "Incursion Max Duration (sec)",
    "Optimal Crate Detour (m)",
    "Guardian Ghost P10 Multiplier",
    "Guardian Ghost P50 Multiplier",
    "Guardian Ghost P90 Multiplier"
]

mae_scores = np.mean(np.abs(val_preds - val_targets), axis=0)
print("\n" + "="*70)
print("  TACTICAL GUARDIAN MODEL VALIDATION PERFORMANCE (RTX 5070)")
print("="*70)
for name, mae in zip(target_names, mae_scores):
    print(f"  • {name:<35}: MAE = {mae:.4f}")
print("="*70)

# ==============================================================================
# 5. EXPORT WEIGHTS & ARCHITECTURE FOR DART ON-DEVICE RUNTIME
# ==============================================================================
# Extract PyTorch weights as flat float lists for zero-dependency native Dart inference
weights_dict = {}
for name, param in model.named_parameters():
    weights_dict[name] = param.detach().cpu().numpy().tolist()

weights_json_str = json.dumps(weights_dict)
weights_path = "assets/models/tactical_guardian_weights.json"
with open(weights_path, "w") as f:
    f.write(weights_json_str)

sha256_hash = hashlib.sha256(weights_json_str.encode("utf-8")).hexdigest()
print(f"[EXPORT] Saved model weights to {weights_path} ({len(weights_json_str)/1024:.1f} KB)")
print(f"[EXPORT] Cryptographic SHA-256: {sha256_hash}")

meta_dict = {
    "model_name": "TacticalGuardianNet",
    "version": "1.0.0",
    "trained_on": torch.cuda.get_device_name(0) if torch.cuda.is_available() else "CPU",
    "train_samples": NUM_SAMPLES,
    "epochs": EPOCHS,
    "sha256": sha256_hash,
    "input_features": [
        "speed_mps", "grade_pct", "cumulative_fatigue", "heading_change_rate",
        "athlete_experience", "cadence_spm", "altitude_m", "territory_density"
    ],
    "x_mean": X_mean.tolist(),
    "x_std": X_std.tolist(),
    "y_mean": Y_mean.tolist(),
    "y_std": Y_std.tolist(),
    "target_names": target_names,
    "mae_metrics": mae_scores.tolist(),
    "best_val_loss": float(best_val_loss)
}

meta_path = "assets/models/tactical_guardian_meta.json"
with open(meta_path, "w") as f:
    json.dump(meta_dict, f, indent=2)
print(f"[EXPORT] Saved metadata to {meta_path}")

# Generate Markdown Report
report_path = "ml/reports/tactical_guardian_training_report.md"
with open(report_path, "w") as f:
    f.write(f"""# Tactical Guardian Deep Neural Network Training Report

**Hardware Acceleration:** {torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'CPU'}  
**PyTorch Version:** {torch.__version__}  
**Training Samples:** {NUM_SAMPLES:,}  
**Training Epochs:** {EPOCHS}  
**SHA-256 Integrity Hash:** `{sha256_hash}`  

## Validation Performance (MAE)
- **Sprint Pace Target:** {mae_scores[0]:.4f} m/s
- **Incursion Max Duration:** {mae_scores[1]:.2f} seconds
- **Optimal Crate Detour:** {mae_scores[2]:.2f} meters
- **Guardian Ghost P10 Multiplier:** {mae_scores[3]:.4f}
- **Guardian Ghost P50 Multiplier:** {mae_scores[4]:.4f}
- **Guardian Ghost P90 Multiplier:** {mae_scores[5]:.4f}

## Key Gameplay Innovations Enabled:
1. **Dynamic HIIT Incursions:** Sprint pacing dynamically tunes to runner fatigue and slope so intervals are exhilarating rather than frustrating.
2. **Procedural Loot Drops:** Crate detours automatically adjust to runner stamina.
3. **Sector Guardian Ghosts:** Competitor ghost runners react naturally to terrain and turns with uncertainty bounds.
""")
print(f"[REPORT] Report written to {report_path}")
print("[SUCCESS] GPU training pipeline finished successfully!")
