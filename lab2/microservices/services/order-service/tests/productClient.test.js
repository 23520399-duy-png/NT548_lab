'use strict';

const { createProductClient, ProductServiceError } = require('../src/productClient');

const jsonResponse = (status, body) => ({ status, ok: status >= 200 && status < 300, json: async () => body });

describe('productClient', () => {
  test('trả về sản phẩm khi HTTP 200', async () => {
    const fetchImpl = jest.fn(async () => jsonResponse(200, { id: 1 }));
    const client = createProductClient('http://product', { fetchImpl });
    await expect(client.getProduct(1)).resolves.toEqual({ id: 1 });
    expect(fetchImpl.mock.calls[0][0]).toBe('http://product/products/1');
  });

  test('trả về null khi HTTP 404', async () => {
    const client = createProductClient('http://product', { fetchImpl: async () => jsonResponse(404, {}) });
    await expect(client.getProduct(9)).resolves.toBeNull();
  });

  test('ném lỗi 502 khi product-service trả lỗi', async () => {
    const client = createProductClient('http://product', { fetchImpl: async () => jsonResponse(500, {}) });
    await expect(client.getProduct(1)).rejects.toMatchObject({ status: 502 });
  });

  test('ném lỗi 503 khi không kết nối được', async () => {
    const client = createProductClient('http://product', {
      fetchImpl: async () => {
        throw new Error('ECONNREFUSED');
      },
    });
    await expect(client.getProduct(1)).rejects.toBeInstanceOf(ProductServiceError);
    await expect(client.getProduct(1)).rejects.toMatchObject({ status: 503 });
  });
});
