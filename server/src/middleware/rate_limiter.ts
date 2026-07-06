/**
 * Rate limiting middleware for WebSocket connections
 */

interface RateLimitEntry {
  timestamps: number[];
  joinedAt: number;
}

class RateLimiter {
  private limits = new Map<string, RateLimitEntry>();
  private readonly windowMs: number;
  private readonly maxRequests: number;
  
  constructor(windowMs: number = 60000, maxRequests: number = 100) {
    this.windowMs = windowMs;
    this.maxRequests = maxRequests;
  }
  
  /**
   * Check if a client is within rate limits.
   * Returns true if allowed, false if rate limited.
   */
  isAllowed(clientId: string, maxRequests?: number): boolean {
    const limit = maxRequests ?? this.maxRequests;
    const now = Date.now();
    
    let entry = this.limits.get(clientId);
    
    if (!entry) {
      entry = { timestamps: [], joinedAt: now };
      this.limits.set(clientId, entry);
    }
    
    // Remove timestamps outside the window
    entry.timestamps = entry.timestamps.filter(
      t => now - t < this.windowMs
    );
    
    if (entry.timestamps.length >= limit) {
      return false;
    }
    
    entry.timestamps.push(now);
    return true;
  }
  
  /**
   * Get remaining requests for a client.
   */
  getRemaining(clientId: string): number {
    const now = Date.now();
    const entry = this.limits.get(clientId);
    
    if (!entry) return this.maxRequests;
    
    const recent = entry.timestamps.filter(t => now - t < this.windowMs);
    return Math.max(0, this.maxRequests - recent.length);
  }
  
  /**
   * Clean up old entries.
   */
  cleanup(): void {
    const now = Date.now();
    for (const [clientId, entry] of this.limits.entries()) {
      entry.timestamps = entry.timestamps.filter(
        t => now - t < this.windowMs
      );
      if (entry.timestamps.length === 0) {
        this.limits.delete(clientId);
      }
    }
  }
  
  /**
   * Reset rate limit for a client.
   */
  reset(clientId: string): void {
    this.limits.delete(clientId);
  }
  
  /**
   * Get stats for monitoring.
   */
  getStats(): { totalClients: number; totalRequests: number } {
    let totalRequests = 0;
    for (const entry of this.limits.values()) {
      totalRequests += entry.timestamps.length;
    }
    return {
      totalClients: this.limits.size,
      totalRequests,
    };
  }
}

export const messageRateLimiter = new RateLimiter(60000, 100);
export const joinRateLimiter = new RateLimiter(60000, 10);
export const fileRateLimiter = new RateLimiter(3600000, 5);

// Run cleanup every 5 minutes
setInterval(() => {
  messageRateLimiter.cleanup();
  joinRateLimiter.cleanup();
  fileRateLimiter.cleanup();
}, 300000);
