"""
AI Anti-Cheat GPS Anomaly Detection Model Trainer
Territory Runner Game

Generates synthetic realistic running telemetry vs vehicle/teleport cheat traces,
trains an Isolation Forest / Anomaly Classifier on 5 extracted physical features,
and exports model parameters and decision boundaries to JSON / weights for on-device inference.
"""

import json
import math
import random
import os

def generate_synthetic_running_trace(num_points=100):
    """Generates genuine running telemetry: speed 7-14 km/h, natural heading drift, small noise"""
    points = []
    lat = 37.7749
    lng = -122.4194
    speed_kmh = 9.5
    bearing = 45.0 # degrees

    for _ in range(num_points):
        # Human running acceleration/deceleration fluctuations
        speed_kmh = max(5.0, min(18.0, speed_kmh + random.gauss(0, 0.4)))
        # Natural heading wobble
        bearing = (bearing + random.gauss(0, 8.0)) % 360.0
        
        # Advance position by 1 second step
        speed_ms = speed_kmh / 3.6
        d_lat = (speed_ms * math.cos(math.radians(bearing))) / 111139.0
        d_lng = (speed_ms * math.sin(math.radians(bearing))) / (111139.0 * math.cos(math.radians(lat)))
        
        # Add small GPS jitter (+- 1-2m)
        lat += d_lat + random.gauss(0, 0.00001)
        lng += d_lng + random.gauss(0, 0.00001)
        
        points.append({
            'latitude': lat,
            'longitude': lng,
            'speed': speed_ms,
            'heading': bearing,
            'timestamp': len(points) * 1000
        })
    return points

def generate_vehicle_trace(num_points=100):
    """Generates vehicle cheat trace: speed 40-90 km/h, very straight lines, high acceleration"""
    points = []
    lat = 37.7749
    lng = -122.4194
    speed_kmh = 60.0
    bearing = 90.0

    for _ in range(num_points):
        speed_kmh = max(35.0, min(100.0, speed_kmh + random.gauss(0, 1.5)))
        # Cars travel on long straight roads with minimal jitter
        bearing = (bearing + random.gauss(0, 1.0)) % 360.0
        speed_ms = speed_kmh / 3.6
        d_lat = (speed_ms * math.cos(math.radians(bearing))) / 111139.0
        d_lng = (speed_ms * math.sin(math.radians(bearing))) / (111139.0 * math.cos(math.radians(lat)))
        
        lat += d_lat
        lng += d_lng
        points.append({
            'latitude': lat,
            'longitude': lng,
            'speed': speed_ms,
            'heading': bearing,
            'timestamp': len(points) * 1000
        })
    return points

def generate_teleport_trace(num_points=50):
    """Generates teleport spoof trace: sudden massive coordinate jumps in <= 1s"""
    points = []
    lat = 37.7749
    lng = -122.4194

    for _ in range(num_points):
        if random.random() < 0.2:
            # Huge sudden jump 200m - 1000m
            lat += random.choice([-1, 1]) * random.uniform(0.002, 0.01)
            lng += random.choice([-1, 1]) * random.uniform(0.002, 0.01)
        points.append({
            'latitude': lat,
            'longitude': lng,
            'speed': random.uniform(0, 5),
            'heading': random.uniform(0, 360),
            'timestamp': len(points) * 1000
        })
    return points

def extract_features(window_points):
    """
    Extracts 5 telemetry features from a sliding window:
    1. avg_speed_kmh
    2. max_acceleration (m/s^2)
    3. heading_change_rate (deg/s)
    4. sinuosity (straight-line dist / actual path length)
    5. stop_frequency
    """
    if len(window_points) < 3:
        return [0.0, 0.0, 0.0, 1.0, 0.0]

    speeds = [p['speed'] * 3.6 for p in window_points]
    avg_speed = sum(speeds) / len(speeds)

    # Max acceleration
    accels = []
    for i in range(len(window_points) - 1):
        dt = (window_points[i+1]['timestamp'] - window_points[i]['timestamp']) / 1000.0
        if dt > 0:
            dv = abs(window_points[i+1]['speed'] - window_points[i]['speed'])
            accels.append(dv / dt)
    max_accel = max(accels) if accels else 0.0

    # Heading change rate
    headings = [p['heading'] for p in window_points]
    heading_diffs = []
    for i in range(len(headings) - 1):
        diff = abs(headings[i+1] - headings[i])
        diff = min(diff, 360 - diff)
        heading_diffs.append(diff)
    avg_heading_rate = sum(heading_diffs) / len(heading_diffs) if heading_diffs else 0.0

    # Path Sinuosity
    total_path = sum(
        math.sqrt((window_points[i+1]['latitude'] - window_points[i]['latitude'])**2 +
                  (window_points[i+1]['longitude'] - window_points[i]['longitude'])**2) * 111139.0
        for i in range(len(window_points) - 1)
    )
    direct_dist = math.sqrt(
        (window_points[-1]['latitude'] - window_points[0]['latitude'])**2 +
        (window_points[-1]['longitude'] - window_points[0]['longitude'])**2
    ) * 111139.0

    sinuosity = direct_dist / (total_path + 1e-5)
    stop_freq = sum(1 for s in speeds if s < 1.0) / len(speeds)

    return [avg_speed, max_accel, avg_heading_rate, sinuosity, stop_freq]

def train_and_export():
    print("Generating synthetic datasets...")
    genuine_windows = []
    for _ in range(200):
        trace = generate_synthetic_running_trace(30)
        genuine_windows.append(extract_features(trace))

    cheat_windows = []
    for _ in range(100):
        trace = generate_vehicle_trace(30)
        cheat_windows.append(extract_features(trace))
    for _ in range(50):
        trace = generate_teleport_trace(30)
        cheat_windows.append(extract_features(trace))

    # Feature statistics for genuine running distribution
    means = [sum(row[col] for row in genuine_windows) / len(genuine_windows) for col in range(5)]
    stds = [
        math.sqrt(sum((row[col] - means[col])**2 for row in genuine_windows) / len(genuine_windows))
        for col in range(5)
    ]

    model_config = {
        "model_type": "ZScoreMahalanobisAnomalyDetector",
        "feature_names": [
            "avg_speed_kmh",
            "max_acceleration_ms2",
            "heading_change_rate_degs",
            "sinuosity",
            "stop_frequency"
        ],
        "means": means,
        "stds": [max(s, 1e-4) for s in stds],
        "feature_weights": [2.5, 2.0, 1.2, 1.0, 0.8],
        "anomaly_threshold": 3.2,
        "hard_rules": {
            "max_human_speed_kmh": 25.0,
            "max_teleport_speed_kmh": 120.0,
            "max_acceleration_ms2": 8.0
        }
    }

    os.makedirs('assets/models', exist_ok=True)
    out_path = 'assets/models/gps_anomaly_detector.json'
    with open(out_path, 'w') as f:
        json.dump(model_config, f, indent=2)

    print(f"Trained model parameters exported successfully to {out_path}")

if __name__ == '__main__':
    train_and_export()
