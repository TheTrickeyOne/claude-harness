---
name: sensor-fusion
description: >-
  IMU/AHRS sensor fusion and IMU driver bring-up. Use when the user mentions
  Madgwick, Mahony, EKF, AHRS, "orientation from accelerometer and gyro",
  quaternion/Euler output, "fuse IMU data", drift correction, magnetometer
  calibration, gyro bias, or bringing up an I2C/SPI IMU (MPU6050/9250, ICM-20948,
  BNO055/BNO085, LSM6DSx, BMI270). Wraps xioTechnologies/Fusion (pip install
  imufusion) to run Madgwick-class fusion offline on logged CSV, and references
  Adafruit_AHRS and kriswiner for on-device algorithm choice. Covers accel/gyro/
  mag calibration, coordinate-frame and sample-rate gotchas, and I2C/SPI driver
  bring-up patterns. Offline analysis is non-destructive; live IMU reads touch a
  bus but do not write device config unless you say so.
---

# Sensor fusion (IMU / AHRS) and IMU bring-up

Senior-engineer stance: fusion problems are almost always **calibration, units,
or coordinate-frame** problems, not algorithm problems. Prove the pipeline on
logged data before you trust anything running on the MCU.

## Prototype offline first with imufusion

`xioTechnologies/Fusion` (the reference AHRS behind many products) has Python
bindings. Validate on a CSV log, then port the tuned params to firmware.

```
pip install imufusion
```

Minimal offline pipeline (gyro in deg/s, accel in g, mag in arbitrary units):

```python
import imufusion, numpy as np

data = np.genfromtxt("imu_log.csv", delimiter=",", skip_header=1)
ts   = data[:, 0]
gyro = data[:, 1:4]   # deg/s
accel= data[:, 4:7]   # g
mag  = data[:, 7:10]  # uT (optional)

ahrs = imufusion.Ahrs()
ahrs.settings = imufusion.Settings(
    imufusion.CONVENTION_NWU,  # match YOUR frame — see gotchas
    0.5,      # gain (higher = trust accel/mag more, faster but noisier)
    2000,     # gyro range deg/s
    10, 10,   # accel/mag rejection thresholds (deg)
    5 * 100)  # recovery period = 5 s * sample rate
euler = []
for i in range(1, len(ts)):
    dt = ts[i] - ts[i-1]
    ahrs.update(gyro[i], accel[i], mag[i], dt)   # or update_no_magnetometer(...)
    euler.append(ahrs.quaternion.to_euler())
euler = np.array(euler)
```

`AhrsFlags` (`.flags`) tells you when accel/mag are being rejected — invaluable
for diagnosing "orientation drifts under vibration". Fusion also ships an
`Offset` gyro-bias helper and a magnetic-calibration routine.

## Choosing the on-device algorithm

- **Fusion / Madgwick**: cheap, quaternion, good default for 6-axis (accel+gyro)
  and 9-axis. Port directly from the C in xioTechnologies/Fusion.
- **Mahony**: even cheaper (PI complementary), fine when you just need to null
  gravity-referenced tilt. See kriswiner's MPU/ICM repos for battle-tested C.
- **Adafruit_AHRS**: Arduino-friendly wrappers around Madgwick/Mahony/NXP Kalman;
  good for quick bring-up on Adafruit sensor boards.
- **EKF / on-sensor fusion**: BNO055/BNO085 (and ICM-20948 DMP) fuse internally
  and hand you a quaternion — no host algorithm needed. Trade CPU for a black box
  you can't tune. Prefer these when you don't want to own the math.

## Calibration — do this or nothing else works

1. **Gyro bias**: hold still, average N samples, subtract. Re-estimate on every
   boot; bias drifts with temperature.
2. **Accel**: at minimum normalize to 1 g at rest. Full 6-position calibration
   solves scale + offset per axis.
3. **Magnetometer** is the hard one. Correct **hard-iron** (offset, from nearby
   permanent magnetics) and **soft-iron** (scale/skew ellipsoid). Collect a
   figure-8 / full-sphere sweep, fit an ellipsoid (MotionCal, or
   `imufusion`'s magnetic calibration). Skipping this makes yaw useless.

## Coordinate-frame and sample-rate gotchas

- **Frame convention** (NED vs ENU vs NWU) must match between how you mount the
  sensor, the sign of each axis, and the fusion setting. A flipped axis looks
  like the filter "diverging". Verify by hand: pitch nose-up, confirm the right
  Euler angle rises.
- **Units**: Fusion/Madgwick expect gyro in **deg/s**. Most IMU registers give
  raw LSB — multiply by the sensitivity for the configured full-scale range.
- **dt / sample rate**: pass real elapsed time per sample. Jitter and dropped
  samples corrupt integration far more than sensor noise. Timestamp at capture,
  not at processing.
- **Gimbal lock**: work in quaternions internally; convert to Euler only for
  display. Don't tune or threshold on Euler.
- **Gyro range vs saturation**: a range set too low clips fast rotations and the
  orientation lags/snaps.

## I2C/SPI IMU driver bring-up

1. **Confirm presence**: read the WHO_AM_I register and check it against the
   datasheet's expected ID before anything else. Wrong value ⇒ wrong address,
   wrong bus, or SPI mode/CS wiring.
2. **Address**: 7-bit; many IMUs have an ADDR/SDO pin toggling the LSB
   (e.g. 0x68/0x69). See the i2c-bringup skill for `i2cdetect` scanning.
3. **SPI**: get CPOL/CPHA (mode 0 vs 3) and max clock right; MSB-of-register =
   read/write bit on most parts. A logic analyzer (sigrok) settles this fast.
4. **Config order**: wake from sleep / soft-reset, set full-scale ranges, set
   ODR and DLPF (bandwidth), enable axes, then read. Match the DLPF bandwidth to
   at least 2x your fusion rate.
5. **Data ready**: prefer the INT/DRDY pin or FIFO over polling to get uniform
   dt. FIFO also survives host latency.
6. **Sanity check raw data** before fusion: at rest, accel magnitude ≈ 1 g, gyro
   ≈ 0. If not, fix the driver — do not paper over it in the filter.

## Workflow

Log raw calibrated accel/gyro(/mag) + timestamps to CSV → tune imufusion offline
until Euler output tracks reality → port the exact settings to the Fusion/Madgwick
C on-device → verify live output matches the offline result.
