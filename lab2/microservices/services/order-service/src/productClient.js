'use strict';

/**
 * Client gọi product-service qua HTTP (fetch có sẵn trong Node >= 18).
 */
class ProductServiceError extends Error {
  constructor(message, status) {
    super(message);
    this.name = 'ProductServiceError';
    this.status = status;
  }
}

function createProductClient(baseUrl, { timeoutMs = 3000, fetchImpl = globalThis.fetch } = {}) {
  return {
    async getProduct(id) {
      let res;
      try {
        res = await fetchImpl(`${baseUrl}/products/${encodeURIComponent(id)}`, {
          signal: AbortSignal.timeout(timeoutMs),
        });
      } catch (err) {
        throw new ProductServiceError(`Không kết nối được product-service: ${err.message}`, 503);
      }
      if (res.status === 404) return null;
      if (!res.ok) {
        throw new ProductServiceError(`product-service trả về HTTP ${res.status}`, 502);
      }
      return res.json();
    },
  };
}

module.exports = { createProductClient, ProductServiceError };
