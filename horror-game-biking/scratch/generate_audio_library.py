import os
import wave
import math
import random
import struct

base_dir = r"d:\Godot\Projekte neu\Der-Heimweg\horror-game-biking\Audio"

directories = [
    os.path.join(base_dir, "Bike"),
    os.path.join(base_dir, "Environment", "Forest"),
    os.path.join(base_dir, "Environment", "Village"),
    os.path.join(base_dir, "Environment", "Wind"),
    os.path.join(base_dir, "Environment", "Rain"),
    os.path.join(base_dir, "Environment", "Ambient"),
    os.path.join(base_dir, "Lights"),
    os.path.join(base_dir, "Objects"),
    os.path.join(base_dir, "Interaction"),
    os.path.join(base_dir, "Vehicles"),
    os.path.join(base_dir, "People"),
    os.path.join(base_dir, "Horror")
]

for d in directories:
    os.makedirs(d, exist_ok=True)

sample_rate = 44100

def write_wav(filename, samples):
    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(1) # mono
        wav_file.setsampwidth(2) # 16-bit
        wav_file.setframerate(sample_rate)
        packed = bytearray()
        for s in samples:
            s_clamped = max(-1.0, min(1.0, s))
            val = int(s_clamped * 32767.0)
            packed.extend(struct.pack('<h', val))
        wav_file.writeframes(packed)

# 1. Bike pedal loop (2s)
dur = 2.0
n_samples = int(sample_rate * dur)
samples = []
for i in range(n_samples):
    t = i / sample_rate
    # rhythmic ticking and gear whirring
    tick = math.sin(2 * math.pi * 4 * t) * (0.3 if math.sin(2 * math.pi * 8 * t) > 0.8 else 0.05)
    whir = math.sin(2 * math.pi * 120 * t) * 0.08
    samples.append(tick + whir + (random.random() * 2 - 1) * 0.02)
write_wav(os.path.join(base_dir, "Bike", "bike_pedal_loop.wav"), samples)

# 2. Bike tire asphalt (2s)
samples = []
lp = 0.0
for i in range(n_samples):
    noise = random.random() * 2 - 1
    lp += (noise - lp) * 0.15
    samples.append(lp * 0.25)
write_wav(os.path.join(base_dir, "Bike", "bike_tire_asphalt.wav"), samples)

# 3. Bike chain loop (2s)
samples = []
for i in range(n_samples):
    t = i / sample_rate
    chain_tick = 0.15 * math.sin(2 * math.pi * 25 * t) * ((random.random() * 0.5) + 0.5)
    samples.append(chain_tick)
write_wav(os.path.join(base_dir, "Bike", "bike_chain_loop.wav"), samples)

# 4. Bike brake (1s)
dur1 = 1.0
samples = []
for i in range(int(sample_rate * dur1)):
    t = i / sample_rate
    squeal = math.sin(2 * math.pi * (1800 + math.sin(t * 10) * 100) * t) * 0.2 * (1.0 - t)
    samples.append(squeal)
write_wav(os.path.join(base_dir, "Bike", "bike_brake.wav"), samples)

# 5. Bike bell (0.8s)
dur_bell = 0.8
samples = []
for i in range(int(sample_rate * dur_bell)):
    t = i / sample_rate
    bell = (math.sin(2 * math.pi * 2400 * t) + math.sin(2 * math.pi * 3100 * t)) * 0.3 * math.exp(-t * 6.0)
    samples.append(bell)
write_wav(os.path.join(base_dir, "Bike", "bike_bell.wav"), samples)

# 6. Bike light switch (0.15s)
samples = []
for i in range(int(sample_rate * 0.15)):
    t = i / sample_rate
    click = (random.random() * 2 - 1) * math.exp(-t * 40.0) * 0.6
    samples.append(click)
write_wav(os.path.join(base_dir, "Bike", "bike_light_switch.wav"), samples)

# 7. Forest night loop (3s)
dur3 = 3.0
n3 = int(sample_rate * dur3)
samples = []
wind_lp = 0.0
for i in range(n3):
    t = i / sample_rate
    noise = random.random() * 2 - 1
    wind_lp += (noise - wind_lp) * 0.03
    cricket = math.sin(2 * math.pi * 4500 * t) * (0.04 if math.sin(2 * math.pi * 12 * t) > 0.85 else 0.0)
    samples.append(wind_lp * 0.3 + cricket)
write_wav(os.path.join(base_dir, "Environment", "Forest", "forest_night_loop.wav"), samples)

# 8. Forest wind light (3s)
samples = []
lp = 0.0
for i in range(n3):
    noise = random.random() * 2 - 1
    lp += (noise - lp) * 0.04
    samples.append(lp * 0.3)
write_wav(os.path.join(base_dir, "Environment", "Forest", "forest_wind_light.wav"), samples)

# 9. Forest bush rustle (0.6s)
samples = []
for i in range(int(sample_rate * 0.6)):
    t = i / sample_rate
    rustle = (random.random() * 2 - 1) * 0.25 * math.sin(math.pi * t / 0.6)
    samples.append(rustle)
write_wav(os.path.join(base_dir, "Environment", "Forest", "forest_bush_rustle.wav"), samples)

# 10. Forest branch creak (0.8s)
samples = []
for i in range(int(sample_rate * 0.8)):
    t = i / sample_rate
    creak = math.sin(2 * math.pi * (150 + t * 400) * t) * 0.15 * math.sin(math.pi * t / 0.8)
    samples.append(creak)
write_wav(os.path.join(base_dir, "Environment", "Forest", "forest_branch_creak.wav"), samples)

# 11. Village car passby far (4s)
dur4 = 4.0
n4 = int(sample_rate * dur4)
samples = []
lp = 0.0
for i in range(n4):
    t = i / sample_rate
    vol = math.sin(math.pi * t / dur4)
    noise = random.random() * 2 - 1
    lp += (noise - lp) * 0.06
    samples.append(lp * vol * 0.3)
write_wav(os.path.join(base_dir, "Environment", "Village", "village_car_passby_far.wav"), samples)

# 12. Village dog bark far (1s)
samples = []
for i in range(int(sample_rate * 1.0)):
    t = i / sample_rate
    bark = math.sin(2 * math.pi * 320 * t) * 0.2 * math.exp(-t * 5.0) if t < 0.4 else 0.0
    samples.append(bark)
write_wav(os.path.join(base_dir, "Environment", "Village", "village_dog_bark_far.wav"), samples)

# 13. Village ambient night (3s)
samples = []
lp = 0.0
for i in range(n3):
    noise = random.random() * 2 - 1
    lp += (noise - lp) * 0.02
    samples.append(lp * 0.2)
write_wav(os.path.join(base_dir, "Environment", "Village", "village_ambient_night.wav"), samples)

# 14. Wind gust soft (3s)
samples = []
lp = 0.0
for i in range(n3):
    t = i / sample_rate
    vol = 0.5 + 0.5 * math.sin(2 * math.pi * 0.33 * t)
    noise = random.random() * 2 - 1
    lp += (noise - lp) * 0.05
    samples.append(lp * vol * 0.35)
write_wav(os.path.join(base_dir, "Environment", "Wind", "wind_gust_soft.wav"), samples)

# 15. Wind night breeze (3s)
samples = []
lp = 0.0
for i in range(n3):
    noise = random.random() * 2 - 1
    lp += (noise - lp) * 0.025
    samples.append(lp * 0.25)
write_wav(os.path.join(base_dir, "Environment", "Wind", "wind_night_breeze.wav"), samples)

# 16. Rain drizzle loop (3s)
samples = []
for i in range(n3):
    rain = (random.random() * 2 - 1) * 0.12
    samples.append(rain)
write_wav(os.path.join(base_dir, "Environment", "Rain", "rain_drizzle_loop.wav"), samples)

# 17. Night crickets loop (3s)
samples = []
for i in range(n3):
    t = i / sample_rate
    c = math.sin(2 * math.pi * 4800 * t) * (0.05 if math.sin(2 * math.pi * 16 * t) > 0.8 else 0.0)
    samples.append(c)
write_wav(os.path.join(base_dir, "Environment", "Ambient", "night_crickets_loop.wav"), samples)

# 18. Streetlight hum (2s)
samples = []
for i in range(n_samples):
    t = i / sample_rate
    hum = (math.sin(2 * math.pi * 50 * t) + math.sin(2 * math.pi * 100 * t) * 0.4) * 0.15
    samples.append(hum)
write_wav(os.path.join(base_dir, "Lights", "streetlight_hum.wav"), samples)

# 19. Streetlight flicker (1s)
samples = []
for i in range(int(sample_rate * 1.0)):
    t = i / sample_rate
    flicker = (math.sin(2 * math.pi * 50 * t) * 0.2) * (1.0 if random.random() > 0.2 else 0.0)
    samples.append(flicker)
write_wav(os.path.join(base_dir, "Lights", "streetlight_flicker.wav"), samples)

# 20. Light switch click (0.1s)
samples = []
for i in range(int(sample_rate * 0.1)):
    t = i / sample_rate
    c = (random.random() * 2 - 1) * math.exp(-t * 50.0) * 0.5
    samples.append(c)
write_wav(os.path.join(base_dir, "Lights", "light_switch_click.wav"), samples)

# 21. Mailbox open (0.4s)
samples = []
for i in range(int(sample_rate * 0.4)):
    t = i / sample_rate
    m = math.sin(2 * math.pi * (400 - t * 200) * t) * 0.2 * math.exp(-t * 6.0)
    samples.append(m)
write_wav(os.path.join(base_dir, "Objects", "mailbox_open.wav"), samples)

# 22. Trashcan lid (0.5s)
samples = []
for i in range(int(sample_rate * 0.5)):
    t = i / sample_rate
    clatter = (random.random() * 2 - 1) * 0.3 * math.exp(-t * 8.0)
    samples.append(clatter)
write_wav(os.path.join(base_dir, "Objects", "trashcan_lid.wav"), samples)

# 23. Door open (0.8s)
samples = []
for i in range(int(sample_rate * 0.8)):
    t = i / sample_rate
    creak = math.sin(2 * math.pi * (180 + t * 60) * t) * 0.18 * math.sin(math.pi * t / 0.8)
    samples.append(creak)
write_wav(os.path.join(base_dir, "Interaction", "door_open.wav"), samples)

# 24. Gate creak (0.9s)
samples = []
for i in range(int(sample_rate * 0.9)):
    t = i / sample_rate
    g = math.sin(2 * math.pi * (220 - t * 80) * t) * 0.2 * math.sin(math.pi * t / 0.9)
    samples.append(g)
write_wav(os.path.join(base_dir, "Interaction", "gate_creak.wav"), samples)

# 25. Car idle far (3s)
samples = []
for i in range(n3):
    t = i / sample_rate
    rumble = math.sin(2 * math.pi * 38 * t) * 0.15 + (random.random() * 2 - 1) * 0.03
    samples.append(rumble)
write_wav(os.path.join(base_dir, "Vehicles", "car_idle_far.wav"), samples)

# 26. Footsteps gravel (0.4s)
samples = []
for i in range(int(sample_rate * 0.4)):
    t = i / sample_rate
    step = (random.random() * 2 - 1) * 0.25 * math.exp(-t * 12.0)
    samples.append(step)
write_wav(os.path.join(base_dir, "People", "footsteps_gravel.wav"), samples)

# 27. Subtle drone night (4s)
samples = []
for i in range(n4):
    t = i / sample_rate
    drone = math.sin(2 * math.pi * 55 * t) * 0.12 + math.sin(2 * math.pi * 110 * t) * 0.05
    samples.append(drone)
write_wav(os.path.join(base_dir, "Horror", "subtle_drone_night.wav"), samples)

# 28. Whisper wind (3s)
samples = []
lp = 0.0
for i in range(n3):
    t = i / sample_rate
    noise = random.random() * 2 - 1
    lp += (noise - lp) * 0.04
    mod = math.sin(2 * math.pi * 0.5 * t) * 0.5 + 0.5
    samples.append(lp * mod * 0.2)
write_wav(os.path.join(base_dir, "Horror", "whisper_wind.wav"), samples)

print("Sound library files generated successfully.")
