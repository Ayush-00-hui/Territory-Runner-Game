#!/usr/bin/env python3
"""
Locomotion & Biomechanical Anti-Cheat Neural Network Trainer
Trained with PyTorch on NVIDIA GeForce RTX 5070 GPU (CUDA).

Classifies athlete movement into 5 distinct locomotion regimes:
  0: HUMAN_RUNNING   - Valid athletic run (captures territory)
  1: HUMAN_WALKING   - Valid pedestrian recovery walk
  2: VEHICLE_TRANSIT - Invalidation (car/motorcycle/bus)
  3: E_SCOOTER_GLIDE - Invalidation (e-scooter/e-bike glide without human cadence)
  4: MOCK_JOYSTICK   - Cheat detection (fake GPS emulator/joystick steps)
"""

import os
import sys
import json
import time
import hashlib
import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import TensorDataset, DataLoader

# Verify CUDA and GPU
device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
print(f"============================================================")
print(f" TERRITORY RUNNER - LOCOMOTION BIOMETRICS NEURAL TRAINER   ")
print(f"============================================================")
print(f"PyTorch Version  : {torch.__version__}")
print(f"Compute Device   : {device}")
if torch.cuda.is_available():
    props = torch.cuda.get_device_properties(0)
    print(f"GPU Hardware     : {props.name}")
    print(f"Total VRAM       : {props.total_memory / (1024**3):.2f} GB")
    print(f"CUDA Capability  : {props.major}.{props.minor}")
    print(f"Multi-Processors : {props.multi_processor_count}")
print(f"============================================================\n")

# Seed for reproducibility
torch.manual_seed(42)
np.random.seed(42)

CLASSES = [
    "HUMAN_RUNNING",
    "HUMAN_WALKING",
    "VEHICLE_TRANSIT",
    "E_SCOOTER_GLIDE",
    "MOCK_JOYSTICK"
]
NUM_CLASSES = len(CLASSES)
WINDOW_SIZE = 32  # 32 sequential sensor frames
NUM_FEATURES = 8  # [speed_mps, accel_mps2, bearing_rate_rads, cadence_spm, vert_osc_cm, gnss_acc_m, jerk_mps3, pitch_deg]

def generate_synthetic_locomotion_dataset(n_samples=12000):
    """
    Generates realistic multi-modal sensor windows based on real biomechanical and GNSS physics.
    """
    print(f"[Dataset] Synthesizing {n_samples} biomechanical & GNSS trajectory windows...")
    X = np.zeros((n_samples, WINDOW_SIZE, NUM_FEATURES), dtype=np.float32)
    y_class = np.zeros(n_samples, dtype=np.int64)
    y_legit = np.zeros(n_samples, dtype=np.float32)

    samples_per_class = n_samples // NUM_CLASSES

    for c in range(NUM_CLASSES):
        start_idx = c * samples_per_class
        end_idx = start_idx + samples_per_class
        
        for i in range(start_idx, end_idx):
            t = np.linspace(0, 3.2, WINDOW_SIZE)
            
            if c == 0:  # HUMAN_RUNNING
                # Speed: 2.5 - 5.5 m/s (9 - 20 km/h) with stride rhythm
                base_speed = np.random.uniform(2.5, 5.5)
                stride_freq = np.random.uniform(2.6, 3.2) # ~160-190 steps/min
                speed = base_speed + 0.3 * np.sin(2 * np.pi * stride_freq * t) + np.random.normal(0, 0.1, WINDOW_SIZE)
                accel = np.gradient(speed, 0.1)
                bearing_rate = np.random.normal(0, 0.08, WINDOW_SIZE) # gentle curves with slow turn rates
                cadence = np.full(WINDOW_SIZE, stride_freq * 60.0) + np.random.normal(0, 3.0, WINDOW_SIZE)
                vert_osc = 8.0 + 3.0 * np.sin(2 * np.pi * stride_freq * t) + np.random.normal(0, 0.5, WINDOW_SIZE) # 6-12 cm bounce
                gnss_acc = np.random.uniform(3.0, 7.0, WINDOW_SIZE)
                jerk = np.gradient(accel, 0.1)
                pitch = np.random.uniform(-4.0, 4.0, WINDOW_SIZE)
                y_legit[i] = 1.0

            elif c == 1:  # HUMAN_WALKING
                # Speed: 1.0 - 1.8 m/s (3.6 - 6.5 km/h)
                base_speed = np.random.uniform(1.0, 1.8)
                stride_freq = np.random.uniform(1.6, 2.0) # ~100-120 steps/min
                speed = base_speed + 0.15 * np.sin(2 * np.pi * stride_freq * t) + np.random.normal(0, 0.05, WINDOW_SIZE)
                accel = np.gradient(speed, 0.1)
                bearing_rate = np.random.normal(0, 0.12, WINDOW_SIZE)
                cadence = np.full(WINDOW_SIZE, stride_freq * 60.0) + np.random.normal(0, 2.0, WINDOW_SIZE)
                vert_osc = 3.5 + 1.0 * np.sin(2 * np.pi * stride_freq * t) + np.random.normal(0, 0.3, WINDOW_SIZE) # 3-5 cm bounce
                gnss_acc = np.random.uniform(2.5, 6.0, WINDOW_SIZE)
                jerk = np.gradient(accel, 0.1)
                pitch = np.random.uniform(-2.0, 2.0, WINDOW_SIZE)
                y_legit[i] = 0.95

            elif c == 2:  # VEHICLE_TRANSIT
                # Speed: 7.0 - 22.0 m/s (25 - 80 km/h)
                base_speed = np.random.uniform(7.0, 22.0)
                speed = base_speed + np.random.normal(0, 0.4, WINDOW_SIZE)
                accel = np.gradient(speed, 0.1)
                bearing_rate = np.random.normal(0, 0.04, WINDOW_SIZE) # high inertial momentum
                cadence = np.random.uniform(0.0, 15.0, WINDOW_SIZE) # near zero pedometer readings
                vert_osc = np.random.uniform(0.0, 1.2, WINDOW_SIZE) # zero biological bounce
                gnss_acc = np.random.uniform(2.0, 8.0, WINDOW_SIZE)
                jerk = np.gradient(accel, 0.1)
                pitch = np.random.uniform(-1.0, 1.0, WINDOW_SIZE)
                y_legit[i] = 0.0

            elif c == 3:  # E_SCOOTER_GLIDE
                # Speed: 4.0 - 8.5 m/s (14 - 30 km/h) with high speed but ZERO human cadence
                base_speed = np.random.uniform(4.0, 8.5)
                speed = base_speed + np.random.normal(0, 0.15, WINDOW_SIZE)
                accel = np.gradient(speed, 0.1)
                bearing_rate = np.random.normal(0, 0.09, WINDOW_SIZE)
                cadence = np.random.uniform(0.0, 12.0, WINDOW_SIZE) # almost zero cadence despite running speed
                vert_osc = np.random.uniform(0.2, 1.0, WINDOW_SIZE) # rigid deck vibration only
                gnss_acc = np.random.uniform(2.5, 6.5, WINDOW_SIZE)
                jerk = np.gradient(accel, 0.1)
                pitch = np.random.uniform(-1.5, 1.5, WINDOW_SIZE)
                y_legit[i] = 0.05

            else:  # MOCK_JOYSTICK
                # Speed: exactly locked at e.g. 3.0 m/s or 5.0 m/s with 0 variance, discrete 45/90 deg turns
                base_speed = np.random.choice([3.0, 4.0, 5.0, 6.0])
                speed = np.full(WINDOW_SIZE, base_speed) # zero natural velocity jitter
                accel = np.zeros(WINDOW_SIZE)
                # discrete mock angles
                bearing_rate = np.random.choice([0.0, 0.785, 1.57], size=WINDOW_SIZE, p=[0.85, 0.1, 0.05])
                cadence = np.zeros(WINDOW_SIZE) # fake GPS generates zero sensor steps
                vert_osc = np.zeros(WINDOW_SIZE) # zero vertical displacement
                gnss_acc = np.full(WINDOW_SIZE, 3.0) # mock location reports synthetic constant 3.0m accuracy
                jerk = np.zeros(WINDOW_SIZE)
                pitch = np.zeros(WINDOW_SIZE)
                y_legit[i] = 0.0

            X[i, :, 0] = speed
            X[i, :, 1] = accel
            X[i, :, 2] = bearing_rate
            X[i, :, 3] = cadence
            X[i, :, 4] = vert_osc
            X[i, :, 5] = gnss_acc
            X[i, :, 6] = jerk
            X[i, :, 7] = pitch
            y_class[i] = c

    # Feature scaling (Z-score normalization stats)
    mean = np.mean(X, axis=(0, 1), keepdims=True)
    std = np.std(X, axis=(0, 1), keepdims=True) + 1e-6
    X_norm = (X - mean) / std

    return X_norm, y_class, y_legit, mean.flatten(), std.flatten()

class LocomotionTemporalNet(nn.Module):
    """
    Temporal 1D Convolution + Multi-Head Attention + Bi-GRU Biomechanical Classifier.
    Runs in sub-2ms on mobile NPU/CPU or desktop GPU.
    """
    def __init__(self, in_features=NUM_FEATURES, num_classes=NUM_CLASSES, hidden_dim=64):
        super().__init__()
        # Temporal feature extraction
        self.conv1 = nn.Conv1d(in_features, hidden_dim, kernel_size=3, padding=1)
        self.conv2 = nn.Conv1d(hidden_dim, hidden_dim, kernel_size=3, padding=1)
        self.bn1 = nn.BatchNorm1d(hidden_dim)
        
        # Self-Attention
        self.attention = nn.MultiheadAttention(embed_dim=hidden_dim, num_heads=4, batch_first=True)
        self.ln_att = nn.LayerNorm(hidden_dim)
        
        # Recurrent sequential dynamics
        self.gru = nn.GRU(hidden_dim, hidden_dim // 2, batch_first=True, bidirectional=True)
        
        # Dual Classification & Legitimacy Heads
        self.fc_shared = nn.Linear(hidden_dim, 32)
        self.fc_class = nn.Linear(32, num_classes)
        self.fc_legit = nn.Linear(32, 1)

    def forward(self, x):
        # x shape: (B, T, C)
        # Permute for Conv1D: (B, C, T)
        h = x.transpose(1, 2)
        h = F.gelu(self.conv1(h))
        h = F.gelu(self.bn1(self.conv2(h)))
        
        # Back to (B, T, hidden_dim)
        h = h.transpose(1, 2)
        
        # Self Attention
        att_out, _ = self.attention(h, h, h)
        h = self.ln_att(h + att_out)
        
        # GRU
        gru_out, _ = self.gru(h)
        # Pool last hidden state
        pooled = gru_out[:, -1, :]
        
        shared = F.gelu(self.fc_shared(pooled))
        logits = self.fc_class(shared)
        legit_score = torch.sigmoid(self.fc_legit(shared)).squeeze(-1)
        
        return logits, legit_score

def train():
    X_norm, y_class, y_legit, norm_mean, norm_std = generate_synthetic_locomotion_dataset(n_samples=12000)
    
    # Split train / test (80/20)
    n_samples = len(X_norm)
    perm = np.random.permutation(n_samples)
    split = int(0.8 * n_samples)
    
    train_idx, test_idx = perm[:split], perm[split:]
    
    X_train = torch.tensor(X_norm[train_idx], dtype=torch.float32)
    y_c_train = torch.tensor(y_class[train_idx], dtype=torch.long)
    y_l_train = torch.tensor(y_legit[train_idx], dtype=torch.float32)
    
    X_test = torch.tensor(X_norm[test_idx], dtype=torch.float32)
    y_c_test = torch.tensor(y_class[test_idx], dtype=torch.long)
    y_l_test = torch.tensor(y_legit[test_idx], dtype=torch.float32)
    
    train_dataset = TensorDataset(X_train, y_c_train, y_l_train)
    test_dataset = TensorDataset(X_test, y_c_test, y_l_test)
    
    batch_size = 128
    train_loader = DataLoader(train_dataset, batch_size=batch_size, shuffle=True)
    test_loader = DataLoader(test_dataset, batch_size=batch_size, shuffle=False)
    
    model = LocomotionTemporalNet().to(device)
    optimizer = torch.optim.AdamW(model.parameters(), lr=1.5e-3, weight_decay=1e-4)
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=25)
    ce_loss_fn = nn.CrossEntropyLoss()
    bce_loss_fn = nn.BCELoss()
    
    epochs = 25
    print(f"\n[Training] Commencing training on {device} ({epochs} epochs, batch_size={batch_size})...")
    start_time = time.time()
    
    for epoch in range(1, epochs + 1):
        model.train()
        total_loss = 0.0
        correct = 0
        total = 0
        
        for batch_x, batch_yc, batch_yl in train_loader:
            batch_x = batch_x.to(device)
            batch_yc = batch_yc.to(device)
            batch_yl = batch_yl.to(device)
            
            optimizer.zero_grad()
            logits, legit_score = model(batch_x)
            
            loss_c = ce_loss_fn(logits, batch_yc)
            loss_l = bce_loss_fn(legit_score, batch_yl)
            loss = loss_c + 0.5 * loss_l
            
            loss.backward()
            optimizer.step()
            
            total_loss += loss.item() * len(batch_x)
            preds = torch.argmax(logits, dim=-1)
            correct += (preds == batch_yc).sum().item()
            total += len(batch_x)
            
        scheduler.step()
        epoch_loss = total_loss / total
        epoch_acc = correct / total * 100.0
        
        vram_mb = torch.cuda.memory_allocated() / (1024**2) if torch.cuda.is_available() else 0.0
        print(f" Epoch {epoch:2d}/{epochs:2d} | Loss: {epoch_loss:.4f} | Train Acc: {epoch_acc:6.2f}% | GPU VRAM: {vram_mb:5.1f} MB | LR: {scheduler.get_last_lr()[0]:.6f}")

    train_duration = time.time() - start_time
    print(f"\n[Completed] Training completed in {train_duration:.2f} seconds.")

    # Evaluation
    model.eval()
    test_correct = 0
    test_total = 0
    class_correct = [0] * NUM_CLASSES
    class_total = [0] * NUM_CLASSES
    
    with torch.no_grad():
        for batch_x, batch_yc, batch_yl in test_loader:
            batch_x = batch_x.to(device)
            batch_yc = batch_yc.to(device)
            logits, legit = model(batch_x)
            preds = torch.argmax(logits, dim=-1)
            
            test_correct += (preds == batch_yc).sum().item()
            test_total += len(batch_x)
            
            for p, y in zip(preds.cpu().numpy(), batch_yc.cpu().numpy()):
                if p == y:
                    class_correct[y] += 1
                class_total[y] += 1
                
    total_acc = test_correct / test_total * 100.0
    print(f"\n============================================================")
    print(f" TEST EVALUATION - LOCOMOTION CLASSIFIER")
    print(f" Overall Accuracy: {total_acc:.2f}% ({test_correct}/{test_total})")
    print(f"------------------------------------------------------------")
    for c in range(NUM_CLASSES):
        c_acc = (class_correct[c] / class_total[c]) * 100.0 if class_total[c] > 0 else 0.0
        print(f"  {CLASSES[c]:16s} : {c_acc:6.2f}% ({class_correct[c]}/{class_total[c]})")
    print(f"============================================================\n")

    # Export Weights and Metadata for Pure Dart Cross-Platform Execution
    print(f"[Export] Serializing model weights and normalization parameters...")
    os.makedirs("assets/models", exist_ok=True)
    
    # Extract linear and conv weights as plain lists
    state = model.state_dict()
    weights_dict = {}
    for k, v in state.items():
        weights_dict[k] = v.cpu().numpy().tolist()
        
    weights_path = "assets/models/locomotion_verifier_weights.json"
    with open(weights_path, "w") as f:
        json.dump(weights_dict, f)
        
    # Compute SHA-256
    with open(weights_path, "rb") as f:
        weights_sha = hashlib.sha256(f.read()).hexdigest()
        
    meta = {
        "model_name": "LocomotionTemporalNet",
        "version": "1.0.0",
        "trained_device": f"{torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'cpu'}",
        "cuda_version": f"{torch.version.cuda if torch.cuda.is_available() else 'N/A'}",
        "window_size": WINDOW_SIZE,
        "num_features": NUM_FEATURES,
        "feature_names": [
            "speed_mps", "accel_mps2", "bearing_rate_rads", "cadence_spm",
            "vert_osc_cm", "gnss_acc_m", "jerk_mps3", "pitch_deg"
        ],
        "classes": CLASSES,
        "test_accuracy": total_acc,
        "norm_mean": norm_mean.tolist(),
        "norm_std": norm_std.tolist(),
        "weights_sha256": weights_sha,
        "exported_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    }
    
    meta_path = "assets/models/locomotion_verifier_meta.json"
    with open(meta_path, "w") as f:
        json.dump(meta, f, indent=2)

    print(f"[Success] Model saved to {weights_path} ({os.path.getsize(weights_path)/(1024*1024):.2f} MB)")
    print(f"[Success] Metadata saved to {meta_path} (SHA-256: {weights_sha[:16]}...)")

if __name__ == "__main__":
    train()
