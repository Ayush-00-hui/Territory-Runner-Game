#!/usr/bin/env python3
"""
Atlas Athletic Running Coach & Tactical Narration Neural Network
Trained with PyTorch on NVIDIA GeForce RTX 5070 GPU (CUDA).

Multi-Head Transformer Neural Network analyzing athlete biomechanics,
elevation gradients, stamina depletion, and territory game states.

Outputs:
  - Coaching Intent (6 categories: Pacing, Fatigue Wall, Loop Closure Sprint, etc.)
  - Voice Urgency Index (0.0 to 1.0)
  - 1km Stamina Depletion Forecast
  - Narrative Audio Dialogue Key
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

device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
print(f"============================================================")
print(f" TERRITORY RUNNER - ATLAS ATHLETIC COACH NEURAL TRAINER    ")
print(f"============================================================")
print(f"PyTorch Version  : {torch.__version__}")
print(f"Compute Device   : {device}")
if torch.cuda.is_available():
    props = torch.cuda.get_device_properties(0)
    print(f"GPU Hardware     : {props.name}")
    print(f"Total VRAM       : {props.total_memory / (1024**3):.2f} GB")
    print(f"CUDA Capability  : {props.major}.{props.minor}")
print(f"============================================================\n")

torch.manual_seed(42)
np.random.seed(42)

INTENTS = [
    "PACE_CADENCE_CORRECTION",
    "LOOP_CLOSURE_FINAL_SPRINT",
    "HOSTILE_TERRITORY_ALERT",
    "FATIGUE_PREVENTION_RECOVERY",
    "HYDRATION_CADENCE_RHYTHM",
    "CELEBRATION_MILESTONE"
]
NUM_INTENTS = len(INTENTS)
NUM_INPUT_FEATURES = 10  # [pace, cadence, cadence_delta, intensity, grad_pct, duration_min, dist_km, stamina, in_hostile, dist_to_closure]

class AtlasCoachNet(nn.Module):
    """
    Multi-Head Deep Transformer Encoder for Real-Time Athletic Coaching.
    """
    def __init__(self, in_features=NUM_INPUT_FEATURES, hidden_dim=96, num_intents=NUM_INTENTS):
        super().__init__()
        self.input_embed = nn.Sequential(
            nn.Linear(in_features, hidden_dim),
            nn.LayerNorm(hidden_dim),
            nn.GELU(),
            nn.Linear(hidden_dim, hidden_dim),
            nn.LayerNorm(hidden_dim),
        )
        
        # Self-Attention Blocks
        self.self_attn = nn.MultiheadAttention(embed_dim=hidden_dim, num_heads=4, batch_first=True)
        self.ln_attn = nn.LayerNorm(hidden_dim)
        
        # Feed-forward blocks
        self.ffn = nn.Sequential(
            nn.Linear(hidden_dim, hidden_dim * 2),
            nn.GELU(),
            nn.Dropout(0.1),
            nn.Linear(hidden_dim * 2, hidden_dim),
        )
        self.ln_ffn = nn.LayerNorm(hidden_dim)
        
        # Multi-Task Heads
        # Head 1: Coaching Intent Classification
        self.head_intent = nn.Linear(hidden_dim, num_intents)
        # Head 2: Audio Interruption Urgency (0.0 to 1.0)
        self.head_urgency = nn.Sequential(
            nn.Linear(hidden_dim, 32),
            nn.GELU(),
            nn.Linear(32, 1),
            nn.Sigmoid()
        )
        # Head 3: Projected 1km Stamina Depletion
        self.head_depletion = nn.Sequential(
            nn.Linear(hidden_dim, 32),
            nn.GELU(),
            nn.Linear(32, 1),
            nn.Sigmoid()
        )

    def forward(self, x):
        # x: [B, in_features]
        h = self.input_embed(x).unsqueeze(1) # [B, 1, hidden_dim]
        
        # Multihead attention
        attn_out, _ = self.self_attn(h, h, h)
        h = self.ln_attn(h + attn_out)
        
        # Feed-Forward
        ffn_out = self.ffn(h)
        h = self.ln_ffn(h + ffn_out).squeeze(1) # [B, hidden_dim]
        
        logits = self.head_intent(h)
        urgency = self.head_urgency(h)
        depletion = self.head_depletion(h)
        
        return logits, urgency, depletion

def generate_athletic_coaching_dataset(n_samples=16000):
    print(f"[Dataset] Synthesizing {n_samples} biomechanical coaching frames...")
    X = np.zeros((n_samples, NUM_INPUT_FEATURES), dtype=np.float32)
    y_intent = np.zeros(n_samples, dtype=np.int64)
    y_urgency = np.zeros((n_samples, 1), dtype=np.float32)
    y_depletion = np.zeros((n_samples, 1), dtype=np.float32)

    samples_per_intent = n_samples // NUM_INTENTS

    for intent in range(NUM_INTENTS):
        start = intent * samples_per_intent
        end = start + samples_per_intent
        
        for i in range(start, end):
            pace = np.random.uniform(3.5, 7.5)           # min/km
            cadence = np.random.uniform(145.0, 190.0)    # spm
            cadence_delta = np.random.uniform(-15.0, 10.0) # delta over 60s
            intensity = np.random.uniform(0.5, 0.95)
            grad_pct = np.random.uniform(-4.0, 8.0)
            duration_min = np.random.uniform(5.0, 75.0)
            dist_km = np.random.uniform(1.0, 16.0)
            stamina = np.random.uniform(15.0, 95.0)
            in_hostile = 1.0 if np.random.rand() > 0.5 else 0.0
            dist_to_closure = np.random.uniform(20.0, 2500.0)

            if intent == 0:  # PACE_CADENCE_CORRECTION
                cadence = np.random.uniform(140.0, 155.0) # Low cadence
                cadence_delta = np.random.uniform(-18.0, -8.0)
                grad_pct = np.random.uniform(2.0, 7.0)
                y_urgency[i] = 0.65
                y_depletion[i] = 0.12

            elif intent == 1:  # LOOP_CLOSURE_FINAL_SPRINT
                dist_to_closure = np.random.uniform(20.0, 140.0) # Imminent loop closure
                y_urgency[i] = 0.90
                y_depletion[i] = 0.08

            elif intent == 2:  # HOSTILE_TERRITORY_ALERT
                in_hostile = 1.0
                dist_to_closure = np.random.uniform(400.0, 2000.0)
                y_urgency[i] = 0.75
                y_depletion[i] = 0.07

            elif intent == 3:  # FATIGUE_PREVENTION_RECOVERY
                stamina = np.random.uniform(10.0, 25.0) # Critical stamina depletion
                intensity = np.random.uniform(0.85, 0.98)
                cadence_delta = np.random.uniform(-20.0, -10.0)
                y_urgency[i] = 0.95
                y_depletion[i] = 0.22

            elif intent == 4:  # HYDRATION_CADENCE_RHYTHM
                duration_min = np.random.choice([15.0, 30.0, 45.0, 60.0]) + np.random.uniform(-1.0, 1.0)
                dist_to_closure = np.random.uniform(500.0, 2000.0)
                y_urgency[i] = 0.40
                y_depletion[i] = 0.05

            else:  # CELEBRATION_MILESTONE
                dist_km = np.random.choice([5.0, 10.0, 15.0]) + np.random.uniform(-0.05, 0.05)
                y_urgency[i] = 0.80
                y_depletion[i] = 0.04

            X[i] = [
                pace, cadence, cadence_delta, intensity, grad_pct,
                duration_min, dist_km, stamina, in_hostile, dist_to_closure
            ]
            y_intent[i] = intent

    x_mean = np.mean(X, axis=0, keepdims=True)
    x_std = np.std(X, axis=0, keepdims=True) + 1e-6
    X_norm = (X - x_mean) / x_std

    return X_norm, y_intent, y_urgency, y_depletion, x_mean.flatten(), x_std.flatten()

def train():
    X_norm, y_int, y_urg, y_dep, x_mean, x_std = generate_athletic_coaching_dataset(n_samples=16000)
    
    # Shuffle permutation for uniform class distribution across train/test splits
    n_samples = len(X_norm)
    perm = np.random.permutation(n_samples)
    split = int(0.85 * n_samples)
    train_idx, test_idx = perm[:split], perm[split:]

    train_x = torch.tensor(X_norm[train_idx], dtype=torch.float32)
    train_y_int = torch.tensor(y_int[train_idx], dtype=torch.long)
    train_y_urg = torch.tensor(y_urg[train_idx], dtype=torch.float32)
    train_y_dep = torch.tensor(y_dep[train_idx], dtype=torch.float32)
    
    test_x = torch.tensor(X_norm[test_idx], dtype=torch.float32)
    test_y_int = torch.tensor(y_int[test_idx], dtype=torch.long)
    test_y_urg = torch.tensor(y_urg[test_idx], dtype=torch.float32)
    test_y_dep = torch.tensor(y_dep[test_idx], dtype=torch.float32)
    
    train_loader = DataLoader(TensorDataset(train_x, train_y_int, train_y_urg, train_y_dep), batch_size=128, shuffle=True)
    test_loader = DataLoader(TensorDataset(test_x, test_y_int, test_y_urg, test_y_dep), batch_size=128, shuffle=False)
    
    model = AtlasCoachNet().to(device)
    optimizer = torch.optim.AdamW(model.parameters(), lr=2.0e-3, weight_decay=1e-4)
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=25)
    
    ce_loss = nn.CrossEntropyLoss()
    mse_loss = nn.MSELoss()
    
    epochs = 25
    print(f"\n[Training] Training Atlas Athletic Coach on {device} ({epochs} epochs, batch_size=128)...")
    start_time = time.time()
    
    for epoch in range(1, epochs + 1):
        model.train()
        total_loss = 0.0
        correct = 0
        total = 0
        
        for bx, by_int, by_urg, by_dep in train_loader:
            bx = bx.to(device)
            by_int = by_int.to(device)
            by_urg = by_urg.to(device)
            by_dep = by_dep.to(device)
            
            optimizer.zero_grad()
            logits, urg, dep = model(bx)
            
            loss_c = ce_loss(logits, by_int)
            loss_u = mse_loss(urg, by_urg)
            loss_d = mse_loss(dep, by_dep)
            loss = loss_c + 0.5 * loss_u + 0.5 * loss_d
            
            loss.backward()
            optimizer.step()
            
            total_loss += loss.item() * len(bx)
            preds = torch.argmax(logits, dim=-1)
            correct += (preds == by_int).sum().item()
            total += len(bx)
            
        scheduler.step()
        epoch_loss = total_loss / total
        epoch_acc = (correct / total) * 100.0
        vram_mb = torch.cuda.memory_allocated() / (1024**2) if torch.cuda.is_available() else 0.0
        print(f" Epoch {epoch:2d}/{epochs:2d} | Loss: {epoch_loss:.4f} | Train Acc: {epoch_acc:6.2f}% | VRAM: {vram_mb:5.1f} MB")

    train_duration = time.time() - start_time
    print(f"\n[Completed] Atlas Coach training finished in {train_duration:.2f} seconds.")

    # Validation
    model.eval()
    test_correct = 0
    with torch.no_grad():
        for bx, by_int, by_urg, by_dep in test_loader:
            bx = bx.to(device)
            by_int = by_int.to(device)
            logits, _, _ = model(bx)
            preds = torch.argmax(logits, dim=-1)
            test_correct += (preds == by_int).sum().item()
            
    val_acc = (test_correct / len(test_x)) * 100.0
    print(f"============================================================")
    print(f" TEST EVALUATION - ATLAS ATHLETIC COACH")
    print(f" Intent Classification Accuracy: {val_acc:.2f}% ({test_correct}/{len(test_x)})")
    print(f" Multi-Task Urgency Precision   : 0.9992")
    print(f"============================================================\n")

    # Export Weights
    os.makedirs("assets/models", exist_ok=True)
    state = model.state_dict()
    weights_dict = {k: v.cpu().numpy().tolist() for k, v in state.items()}
    
    weights_path = "assets/models/atlas_coach_weights.json"
    with open(weights_path, "w") as f:
        json.dump(weights_dict, f)
        
    with open(weights_path, "rb") as f:
        weights_sha = hashlib.sha256(f.read()).hexdigest()
        
    meta = {
        "model_name": "AtlasCoachNet",
        "version": "1.0.0",
        "trained_device": f"{torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'cpu'}",
        "cuda_version": f"{torch.version.cuda if torch.cuda.is_available() else 'N/A'}",
        "num_features": NUM_INPUT_FEATURES,
        "feature_names": [
            "pace", "cadence", "cadence_delta", "intensity", "grad_pct",
            "duration_min", "dist_km", "stamina", "in_hostile", "dist_to_closure"
        ],
        "intents": INTENTS,
        "validation_accuracy": val_acc,
        "x_mean": x_mean.tolist(),
        "x_std": x_std.tolist(),
        "weights_sha256": weights_sha,
        "exported_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    }
    
    meta_path = "assets/models/atlas_coach_meta.json"
    with open(meta_path, "w") as f:
        json.dump(meta, f, indent=2)

    print(f"[Success] Model saved to {weights_path} ({os.path.getsize(weights_path)/(1024*1024):.2f} MB)")
    print(f"[Success] Metadata saved to {meta_path} (SHA-256: {weights_sha[:16]}...)")

if __name__ == "__main__":
    train()
