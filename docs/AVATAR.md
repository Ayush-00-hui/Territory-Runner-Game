# Territory Runner — Vector Runner Avatar & Wardrobe System

## 1. Overview
The **Runner Avatar System** provides a pure Flutter vector-drawn athletic avatar buddy for Territory Runner. It requires **zero external runtime dependencies** (no Rive, no Lottie, no raster PNG/WebP sprites, no 3D meshes). All rendering is handled natively through Flutter's `CustomPainter` API using mathematical kinematic equations and responsive vector paths.

### Key Capabilities
- **Real-Time Kinematic Animation:** Harmonic stride cycling for running, pacing, and stationary athletic ready stances.
- **Dynamic Modular Wardrobe:** 6 categories (Headwear, Tops, Bottoms, Shoes, Accessories, Body Tone) with 60 athletic items.
- **Honest Unlock Progression:** Automatic unlock evaluation based on verified athlete metrics (Runner Level, Total Distance Km, Daily Run Streak, and Default/Free items).
- **Offline-First & Privacy First:** Avatar choices are persisted strictly on the device in Hive box `avatar_v1`. Avatar selections and wardrobe choices are **never transmitted** over the network, analytics, push notifications, or telemetry.

---

## 2. Vector Kinematics & Rendering Architecture

### 2.1 The Stride Harmonic Model
The avatar's running animation is driven by an `AnimationController` cycling with duration $T = 780\text{ ms}$ (cadence $\approx 154\text{ steps/min}$ or $1.28\text{ Hz}$):

$$\theta(t) = 2\pi \cdot t, \quad t \in [0, 1]$$

* **Pelvic Bounce & Torso Lean:**
  $$\Delta y_{\text{pelvis}} = -|\sin(\theta)| \cdot 3.5 \cdot s$$
  $$\text{forward lean} = 7^\circ \text{ athletic forward tilt}$$
* **Hip & Knee Articulation:**
  $$\alpha_{\text{leg1}} = \sin(\theta) \cdot 0.70\text{ rad} \quad (\approx 40^\circ)$$
  $$\alpha_{\text{leg2}} = -\sin(\theta) \cdot 0.70\text{ rad}$$
* **Arm Counter-Phase Swing:**
  $$\alpha_{\text{arm1}} = -\sin(\theta) \cdot 0.65\text{ rad} \quad (\approx 37^\circ)$$
  $$\alpha_{\text{arm2}} = \sin(\theta) \cdot 0.65\text{ rad}$$

### 2.2 Layering Pipeline
To guarantee proper visual depth during running and stationary poses, the painter renders components in 6 strict depth layers:
1. **Back Arm:** Back shoulder pivot, upper arm, elbow joint, forearm, wrist tracker.
2. **Back Leg:** Back hip pivot, thigh, knee, calf, ankle, back running shoe.
3. **Torso & Bottoms:** Pelvis, running shorts/tights, athletic singlet/tank/jacket, chest details.
4. **Head & Hair:** Neck, facial oval, headband/cap/visor, eye visor/sunglasses.
5. **Front Leg:** Front hip pivot, thigh, knee, calf, ankle, front running shoe.
6. **Front Arm & Hand:** Front shoulder pivot, upper arm, forearm, hand/wrist accessories.

### 2.3 Reduced Motion & Accessibility
When `MediaQuery.of(context).disableAnimations` is `true`:
- Stride animations halt automatically.
- The avatar renders in a poised, balanced standing athletic stance (`isReadyPose: true`).
- Zero continuous CPU/GPU rendering ticks occur when the screen is idle.

---

## 3. Wardrobe Catalog (60 Items)

The wardrobe contains 10 carefully designed athletic items across each of the 6 categories:

### 3.1 Headwear
| Item ID | Display Name | Unlock Condition | Primary Palette | Secondary Palette | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `head_none` | Bare Head | Free | `#00000000` | `#00000000` | Classic natural runner look without headwear |
| `head_mustard_band` | Mustard Sweatband | Level 1 | `#F2C94C` | `#121417` | High-visibility moisture-wicking athletic headband |
| `head_electric_visor` | Electric Blue Visor | Level 2 | `#2D9CDB` | `#FFFFFF` | Aerodynamic sun visor for open-sky road sprints |
| `head_obsidian_cap` | Midnight Trail Cap | Distance 25 km | `#1E2229` | `#F2C94C` | Lightweight breathable nylon trail cap |
| `head_coral_band` | Coral Focus Band | Streak 3 days | `#FF6B6B` | `#121417` | High-tempo sprint sweatband |
| `head_mesh_trucker` | Vent Mesh Runner Cap | Level 4 | `#2A2F38` | `#2D9CDB` | Maximum-breathability summer mesh runner cap |
| `head_thermal_beanie` | Alpine Thermal Beanie | Distance 50 km | `#121417` | `#828282` | Cold-weather merino running beanie |
| `head_carbon_visor` | Carbon Race Visor | Streak 7 days | `#0B0C0E` | `#F2C94C` | Ultralight race day performance visor |
| `head_glacier_band` | Glacier Chill Band | Level 6 | `#56CCF2` | `#FFFFFF` | Cooling polymer sweatband for summer miles |
| `head_championship_crown` | Champion Laurels | Level 10 | `#F2C94C` | `#FFFFFF` | Minimalist athletic laurels for veteran athletes |

### 3.2 Tops
| Item ID | Display Name | Unlock Condition | Primary Palette | Secondary Palette | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `top_classic_black_tee` | Core Training Tee | Free | `#1E2229` | `#2A2F38` | Anti-chafing breathable short sleeve training tee |
| `top_pro_tank_yellow` | Mustard Speed Tank | Level 2 | `#F2C94C` | `#121417` | Featherweight singlet designed for race pace |
| `top_blue_windbreaker` | Aero Electric Windbreaker | Level 3 | `#2D9CDB` | `#1E2229` | Ripstop weather-resistant pacing shell |
| `top_coral_singlet` | Coral Tempo Singlet | Streak 5 days | `#FF6B6B` | `#F2C94C` | Targeted cooling panels for threshold workouts |
| `top_slate_longsleeve` | Slate Thermal Long Sleeve | Distance 30 km | `#2A2F38` | `#2D9CDB` | Articulated sleeves for cold morning warmups |
| `top_white_elite_singlet`| Podium Race Singlet | Level 5 | `#F2F4F7` | `#121417` | Ultra-breathable heat-dissipating race jersey |
| `top_trail_vest` | Territory Master Vest | Distance 100 km| `#1E2229` | `#F2C94C` | Integrated hydration and contour utility harness |
| `top_highvis_jacket` | High-Vis Neon Jacket | Streak 14 days| `#F2C94C` | `#2D9CDB` | 360-degree reflective storm running jacket |
| `top_stealth_hoodie` | Carbon Stealth Sleeveless | Level 7 | `#121417` | `#2A2F38` | Heavy-duty athletic fleece for outdoor grit |
| `top_legend_jersey` | Grandmaster Gold Singlet| Level 10 | `#F2C94C` | `#FF6B6B` | Distinctive top awarded to premier runners |

### 3.3 Bottoms
| Item ID | Display Name | Unlock Condition | Primary Palette | Secondary Palette | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `bot_standard_shorts` | 5" Training Shorts | Free | `#1E2229` | `#2A2F38` | Lightweight 4-way stretch running shorts |
| `bot_split_shorts_yellow`| 3" Mustard Split Shorts | Level 2 | `#F2C94C` | `#121417` | Unrestricted stride freedom for speed workouts |
| `bot_compression_tights` | Electric Full Compression | Level 3 | `#2D9CDB` | `#121417` | Muscle stabilization and recovery tights |
| `bot_half_tights_black` | Carbon Speed Half Tights | Distance 20 km | `#121417` | `#2A2F38` | Aerodynamic ergonomic racing half tights |
| `bot_trail_cargo_shorts` | Trail Storage Shorts | Distance 40 km | `#2A2F38` | `#F2C94C` | Multi-pocket shorts for long-range runs |
| `bot_coral_tempo_shorts` | Coral Stride Shorts | Streak 4 days | `#FF6B6B` | `#121417` | Moisture-wicking liner shorts for tempo runs |
| `bot_reflective_tights` | Night-Runner Tights | Streak 10 days| `#1E2229` | `#2D9CDB` | High-contrast luminescent lower leg paneling |
| `bot_elite_split_shorts` | Minimalist Elite Splits | Level 6 | `#F2F4F7` | `#121417` | Featherweight racing shorts with side overlap |
| `bot_weatherproof_pants` | Tapered Storm Track Pants| Distance 80 km | `#121417` | `#2D9CDB` | Articulated knees with windproof barrier |
| `bot_championship_tights`| Gold Pacing Tights | Level 10 | `#121417` | `#F2C94C` | Premium gold trim athlete half tights |

### 3.4 Shoes
| Item ID | Display Name | Unlock Condition | Primary Palette | Secondary Palette | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `shoe_trainer_grey` | Daily Cushion Trainer | Free | `#828282` | `#FFFFFF` | Balanced daily road miles training shoe |
| `shoe_mustard_racer` | Mustard Carbon Super-Shoe| Level 2 | `#F2C94C` | `#121417` | Carbon-plated high energy return racer |
| `shoe_electric_tempo` | Electric Blue Tempo Flat | Level 4 | `#2D9CDB` | `#FFFFFF` | Responsive lightweight road racing shoe |
| `shoe_coral_spikes` | Coral Track Sprint Spikes| Streak 5 days | `#FF6B6B` | `#F2C94C` | Aggressive traction for maximum velocity |
| `shoe_trail_lug` | Grip-Master Trail Lugs | Distance 50 km | `#1E2229` | `#2D9CDB` | Deep lugged vibram outsole for rough trails |
| `shoe_triple_black` | Stealth Carbon Striders | Distance 75 km | `#121417` | `#2A2F38` | Monochromatic cushioned long-run shoe |
| `shoe_podium_white` | Pure White Marathon Pro | Level 7 | `#F2F4F7` | `#2D9CDB` | Pristine elite distance marathon shoe |
| `shoe_neon_endurance` | Luminescent Max Cushion | Streak 12 days| `#F2C94C` | `#2D9CDB` | High-stack protective recovery shoes |
| `shoe_storm_bootie` | GORE Shield All-Weather | Distance 150 km| `#2A2F38` | `#FF6B6B` | Weatherproof running bootie with seal |
| `shoe_champion_gold` | Grand Prix Gold Racers | Level 10 | `#F2C94C` | `#121417` | Gilded carbon marathon racing footwear |

### 3.5 Accessories
| Item ID | Display Name | Unlock Condition | Primary Palette | Secondary Palette | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `acc_none` | Minimalist (No Gear) | Free | `#00000000` | `#00000000` | Pure unencumbered running |
| `acc_sport_watch_black` | GPS Lap Pacer Watch | Level 1 | `#1E2229` | `#2D9CDB` | Real-time wrist-based split timing unit |
| `acc_sunglasses_coral` | High-Contrast Coral Shades| Level 3 | `#FF6B6B` | `#121417` | Polarized optical glare shields |
| `acc_armband_phone` | Armband Device Holder | Distance 15 km | `#2A2F38` | `#F2C94C` | Secure upper-arm phone sleeve |
| `acc_mustard_wristband` | Dual Mustard Sweat Cuffs | Streak 3 days | `#F2C94C` | `#121417` | Terrycloth athletic sweat absorbers |
| `acc_reflective_sash` | Night Reflective Vest | Streak 7 days | `#F2C94C` | `#2D9CDB` | High-visibility crossing torso harness |
| `acc_hydration_flask` | Handheld Soft Flask | Distance 60 km | `#2D9CDB` | `#FFFFFF` | Ergonomic 500ml quick-grip hydration flask |
| `acc_aero_sunglasses` | Frameless Speed Shades | Level 6 | `#2D9CDB` | `#121417` | Panoramic aerodynamic racing eyewear |
| `acc_scout_beacon` | Territory Scout Beacon | Distance 100 km| `#2D9CDB` | `#F2C94C` | Frontier territory surveyor arm tracker beacon |
| `acc_champion_medal` | Gold Finisher Pendant | Level 10 | `#F2C94C` | `#121417` | Heavy engraved victory medallion |

### 3.6 Skin / Body Tones
| Item ID | Display Name | Unlock Condition | Primary Palette | Secondary Palette | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `tone_warm_sand` | Warm Sand | Free | `#E8BEAC` | `#C89985` | Natural athletic skin tone 1 |
| `tone_golden_amber` | Golden Amber | Free | `#D89B6E` | `#B87B4E` | Natural athletic skin tone 2 |
| `tone_rich_chestnut`| Rich Chestnut | Free | `#8D5524` | `#6D380F` | Natural athletic skin tone 3 |
| `tone_deep_espresso`| Deep Espresso | Free | `#4A2C18` | `#321C0E` | Natural athletic skin tone 4 |
| `tone_fair_peach` | Fair Peach | Free | `#F5D0C5` | `#DBA99A` | Natural athletic skin tone 5 |
| `tone_sun_bronze` | Sun Bronze | Free | `#BA7A50` | `#965C34` | Natural athletic skin tone 6 |
| `tone_deep_bronze` | Deep Bronze | Free | `#704128` | `#502A16` | Natural athletic skin tone 7 |
| `tone_olive_tan` | Olive Tan | Free | `#C69A7B` | `#A67858` | Natural athletic skin tone 8 |
| `tone_ivory_warm` | Warm Ivory | Free | `#FBE3D6` | `#E0BCAC` | Natural athletic skin tone 9 |
| `tone_dark_cocoa` | Dark Cocoa | Free | `#361F13` | `#24140B` | Natural athletic skin tone 10 |

---

## 4. How to Add a New Wardrobe Item

Adding a new wardrobe item takes 3 simple steps:

### Step 1: Append Item to `WardrobeCatalog`
In [`lib/models/wardrobe_catalog.dart`](file:///c:/Users/ARNAV%20ARYA/territory-runner/lib/models/wardrobe_catalog.dart):
```dart
WardrobeItem(
  id: 'top_neon_blaze',
  name: 'Neon Blaze Singlet',
  category: WardrobeCategory.top,
  primaryColor: const Color(0xFF00FF88),
  accentColor: const Color(0xFF121417),
  description: 'Ultra-bright luminescent race day top',
  unlockCondition: const WardrobeUnlockCondition.level(8),
),
```

### Step 2: Ensure Painter Rendering Hook
If the item uses existing geometric category paths (singlets, tees, shorts, tights, shoes, caps, visors), `RunnerAvatarPainter` will automatically apply the item's `primaryColor` and `accentColor`. If the item requires unique vector shapes:
1. Open [`lib/ui/widgets/runner_avatar_painter.dart`](file:///c:/Users/ARNAV%20ARYA/territory-runner/lib/ui/widgets/runner_avatar_painter.dart).
2. Locate the corresponding drawing method (`_drawHead`, `_drawTorso`, `_drawLeg`, `_drawArm`).
3. Add specific vector path logic checking `item.id == 'top_neon_blaze'`.

### Step 3: Run Verification Tests
```bash
flutter test test/ui/avatar_and_wardrobe_test.dart
flutter test test/banned_words_audit_test.dart
flutter analyze
```

---

## 5. Storage, Persistence, and Privacy
- **Box Name:** `avatar_v1`
- **Data Key:** `runner_avatar_state`
- **Model:** [`RunnerAvatar`](file:///c:/Users/ARNAV%20ARYA/territory-runner/lib/models/runner_avatar.dart) (serializes directly to JSON with safe default fallback).
- **Zero Cloud Leakage:** Avatar selections are purely client-side customization.
- **Account Deletion / Wipe Compliance:** When the user taps **"Clear all local data"** or deletes their account, `AvatarService.instance.clear()` is invoked, purging the Hive box permanently.

