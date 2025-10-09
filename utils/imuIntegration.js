/**
 * IMU Integration Utility
 * Integrates accelerometer data to calculate position in 3D space
 */

class IMUIntegrator {
  constructor() {
    this.reset();
  }

  reset() {
    // Velocity in m/s for each axis
    this.velocity = { x: 0, y: 0, z: 0 };
    
    // Position in meters for each axis
    this.position = { x: 0, y: 0, z: 0 };
    
    // Previous timestamp for calculating time delta
    this.lastTimestamp = null;
    
    // Previous acceleration for trapezoidal integration
    this.lastAccel = { x: 0, y: 0, z: 0 };
  }

  /**
   * Integrate acceleration data to update velocity and position
   * @param {Object} accel - Acceleration in m/s² {x, y, z}
   * @param {Number} timestamp - Current timestamp in milliseconds
   * @returns {Object} Current position {x, y, z} in meters
   */
  integrate(accel, timestamp) {
    // Parse acceleration values
    const ax = parseFloat(accel.x) || 0;
    const ay = parseFloat(accel.y) || 0;
    const az = parseFloat(accel.z) || 0;

    // Initialize timestamp on first call
    if (this.lastTimestamp === null) {
      this.lastTimestamp = timestamp;
      this.lastAccel = { x: ax, y: ay, z: az };
      return { ...this.position };
    }

    // Calculate time delta in seconds
    const dt = (timestamp - this.lastTimestamp) / 1000.0;
    
    // Prevent integration with unrealistic time deltas
    if (dt <= 0 || dt > 1.0) {
      this.lastTimestamp = timestamp;
      return { ...this.position };
    }

    // Gravity compensation (assuming Z-axis is vertical)
    // Remove gravity (9.81 m/s²) from z-axis
    const az_compensated = az - 9.81;

    // Trapezoidal integration for velocity
    // v = v0 + (a0 + a1) * dt / 2
    this.velocity.x += (this.lastAccel.x + ax) * dt / 2;
    this.velocity.y += (this.lastAccel.y + ay) * dt / 2;
    this.velocity.z += (this.lastAccel.z + az_compensated) * dt / 2;

    // Apply velocity dampening to reduce drift
    // Small velocities decay to zero over time
    const damping = 0.98;
    this.velocity.x *= damping;
    this.velocity.y *= damping;
    this.velocity.z *= damping;

    // Integrate velocity to get position
    // p = p0 + v * dt
    this.position.x += this.velocity.x * dt;
    this.position.y += this.velocity.y * dt;
    this.position.z += this.velocity.z * dt;

    // Update last values
    this.lastAccel = { x: ax, y: ay, z: az_compensated };
    this.lastTimestamp = timestamp;

    return { ...this.position };
  }

  /**
   * Get current position
   * @returns {Object} Current position {x, y, z} in meters
   */
  getPosition() {
    return { ...this.position };
  }

  /**
   * Get current velocity
   * @returns {Object} Current velocity {x, y, z} in m/s
   */
  getVelocity() {
    return { ...this.velocity };
  }
}

export default IMUIntegrator;
