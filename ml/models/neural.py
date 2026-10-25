"""
Lightweight 1D-CNN + GRU Deep Neural Network (PyTorch)
Territory Runner ML Anti-Cheat Engine

A small temporal neural network operating over sequential GPS breadcrumb kinematics:
- 1D-CNN: Extracts local multi-point temporal motifs (accel spikes, quick turns).
- Bidirectional GRU: Captures long-range temporal dependencies and pacing rhythm.
- Fully connected head: Outputs calibrated anomaly probability.
"""

import random
from typing import Optional, Tuple

import numpy as np
import torch
import torch.nn as nn
from torch.utils.data import DataLoader, TensorDataset

RANDOM_SEED = 42
random.seed(RANDOM_SEED)
np.random.seed(RANDOM_SEED)
torch.manual_seed(RANDOM_SEED)
if torch.cuda.is_available():
    torch.cuda.manual_seed_all(RANDOM_SEED)


class TemporalKinematicNet(nn.Module):
    """Small 1D-CNN + Bidirectional GRU architecture for sequence classification."""

    def __init__(self, in_channels: int = 5, cnn_channels: int = 16, gru_hidden: int = 32, dropout: float = 0.2):
        super().__init__()
        # 1D-CNN front-end across sequence points
        self.conv = nn.Conv1d(in_channels=in_channels, out_channels=cnn_channels, kernel_size=3, padding=1)
        self.bn = nn.BatchNorm1d(cnn_channels)
        self.relu = nn.ReLU()

        # Recurrent GRU stage
        self.gru = nn.GRU(
            input_size=cnn_channels,
            hidden_size=gru_hidden,
            batch_first=True,
            bidirectional=True,
        )

        # Classification head (bidirectional = 2 * gru_hidden)
        self.fc = nn.Sequential(
            nn.Dropout(dropout),
            nn.Linear(gru_hidden * 2, 16),
            nn.ReLU(),
            nn.Linear(16, 1),
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        # x shape: [batch, seq_len, in_channels]
        # Conv1d expects: [batch, in_channels, seq_len]
        x_trans = x.transpose(1, 2)
        c = self.relu(self.bn(self.conv(x_trans)))

        # Transpose back for GRU: [batch, seq_len, cnn_channels]
        c_trans = c.transpose(1, 2)
        out, _ = self.gru(c_trans)

        # Global average pooling across time steps
        pooled = torch.mean(out, dim=1)
        logits = self.fc(pooled)
        return logits.squeeze(-1)


class NeuralSequenceClassifier:
    """Scikit-learn compatible wrapper for TemporalKinematicNet."""

    def __init__(
        self,
        in_channels: int = 5,
        epochs: int = 15,
        batch_size: int = 64,
        lr: float = 0.002,
        device: Optional[str] = None,
    ):
        self.in_channels = in_channels
        self.epochs = epochs
        self.batch_size = batch_size
        self.lr = lr
        self.device = device or ("cuda" if torch.cuda.is_available() else "cpu")
        self.model: Optional[TemporalKinematicNet] = None

    def fit(self, X: np.ndarray, y: np.ndarray) -> "NeuralSequenceClassifier":
        """Fits network on sequential kinematics [N, seq_len, channels]."""
        torch.manual_seed(RANDOM_SEED)
        self.model = TemporalKinematicNet(in_channels=self.in_channels).to(self.device)

        X_t = torch.tensor(X, dtype=torch.float32)
        y_t = torch.tensor(y, dtype=torch.float32)

        # Calculate class weighting for imbalanced loss
        pos_count = max(1, int(np.sum(y == 1)))
        neg_count = max(1, int(np.sum(y == 0)))
        pos_weight = torch.tensor([neg_count / pos_count], dtype=torch.float32).to(self.device)

        criterion = nn.BCEWithLogitsLoss(pos_weight=pos_weight)
        optimizer = torch.optim.AdamW(self.model.parameters(), lr=self.lr, weight_decay=1e-4)

        dataset = TensorDataset(X_t, y_t)
        loader = DataLoader(dataset, batch_size=self.batch_size, shuffle=True, drop_last=False)

        self.model.train()
        for epoch in range(self.epochs):
            for batch_x, batch_y in loader:
                batch_x = batch_x.to(self.device)
                batch_y = batch_y.to(self.device)

                optimizer.zero_grad()
                logits = self.model(batch_x)
                loss = criterion(logits, batch_y)
                loss.backward()
                optimizer.step()

        return self

    def predict_proba(self, X: np.ndarray) -> np.ndarray:
        """Predicts probabilities [P(0), P(1)]."""
        if self.model is None:
            raise RuntimeError("Model must be fitted before predict_proba.")

        self.model.eval()
        X_t = torch.tensor(X, dtype=torch.float32)
        loader = DataLoader(TensorDataset(X_t), batch_size=512, shuffle=False)

        probs_pos = []
        with torch.no_grad():
            for (batch_x,) in loader:
                batch_x = batch_x.to(self.device)
                logits = self.model(batch_x)
                p = torch.sigmoid(logits)
                probs_pos.extend(p.cpu().numpy().tolist())

        p1 = np.array(probs_pos, dtype=np.float64)
        p0 = 1.0 - p1
        return np.column_stack([p0, p1])

    def predict(self, X: np.ndarray, threshold: float = 0.5) -> np.ndarray:
        """Binary predictions."""
        p1 = self.predict_proba(X)[:, 1]
        return (p1 >= threshold).astype(int)
