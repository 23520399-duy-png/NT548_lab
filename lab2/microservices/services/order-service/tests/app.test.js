'use strict';

const request = require('supertest');
const { createApp } = require('../src/app');
const { ProductServiceError } = require('../src/productClient');

const PRODUCTS = {
  1: { id: 1, name: 'Bàn phím cơ', price: 850000, stock: 20 },
  2: { id: 2, name: 'Tai nghe', price: 1250000, stock: 1 },
};

function fakeClient() {
  return { getProduct: jest.fn(async (id) => PRODUCTS[id] || null) };
}

describe('order-service', () => {
  let app;
  let client;

  beforeEach(() => {
    client = fakeClient();
    app = createApp({ productClient: client });
  });

  test('GET /health', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ status: 'ok', service: 'order-service' });
  });

  test('GET /orders rỗng lúc đầu', async () => {
    const res = await request(app).get('/orders');
    expect(res.status).toBe(200);
    expect(res.body).toEqual([]);
  });

  test('POST /orders tạo đơn và tính tổng tiền', async () => {
    const res = await request(app).post('/orders').send({ productId: 1, quantity: 2 });
    expect(res.status).toBe(201);
    expect(res.body).toMatchObject({ id: 1, productId: 1, quantity: 2, total: 1700000 });
    expect(client.getProduct).toHaveBeenCalledWith(1);

    const detail = await request(app).get('/orders/1');
    expect(detail.status).toBe(200);
    expect(detail.body.productName).toBe('Bàn phím cơ');
  });

  test('GET /orders/:id không tồn tại -> 404', async () => {
    const res = await request(app).get('/orders/42');
    expect(res.status).toBe(404);
  });

  test.each([
    [{ productId: 0, quantity: 1 }],
    [{ productId: 'a', quantity: 1 }],
    [{ productId: 1, quantity: 0 }],
    [{ productId: 1 }],
  ])('POST /orders dữ liệu sai %j -> 400', async (body) => {
    const res = await request(app).post('/orders').send(body);
    expect(res.status).toBe(400);
  });

  test('POST /orders sản phẩm không tồn tại -> 404', async () => {
    const res = await request(app).post('/orders').send({ productId: 99, quantity: 1 });
    expect(res.status).toBe(404);
  });

  test('POST /orders vượt tồn kho -> 409', async () => {
    const res = await request(app).post('/orders').send({ productId: 2, quantity: 5 });
    expect(res.status).toBe(409);
    expect(res.body.available).toBe(1);
  });

  test('product-service lỗi -> trả về mã lỗi tương ứng', async () => {
    client.getProduct.mockRejectedValueOnce(new ProductServiceError('down', 503));
    const res = await request(app).post('/orders').send({ productId: 1, quantity: 1 });
    expect(res.status).toBe(503);
    expect(res.body.error).toBe('down');
  });

  test('lỗi không xác định -> 500 và không lộ chi tiết', async () => {
    client.getProduct.mockRejectedValueOnce(new Error('secret detail'));
    const res = await request(app).post('/orders').send({ productId: 1, quantity: 1 });
    expect(res.status).toBe(500);
    expect(res.body.error).toBe('Lỗi hệ thống');
  });
});
