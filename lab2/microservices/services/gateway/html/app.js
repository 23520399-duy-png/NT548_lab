'use strict';

const vnd = (n) => n.toLocaleString('vi-VN') + ' ₫';

function cell(text) {
  const td = document.createElement('td');
  td.textContent = text;
  return td;
}

async function loadProducts() {
  const res = await fetch('/api/products');
  const products = await res.json();
  const body = document.querySelector('#products tbody');
  body.replaceChildren();
  for (const p of products) {
    const tr = document.createElement('tr');
    tr.append(cell(p.id), cell(p.name), cell(vnd(p.price)), cell(p.stock));
    const td = document.createElement('td');
    const btn = document.createElement('button');
    btn.textContent = 'Đặt 1';
    btn.addEventListener('click', () => order(p.id));
    td.append(btn);
    tr.append(td);
    body.append(tr);
  }
}

async function loadOrders() {
  const res = await fetch('/api/orders');
  const orders = await res.json();
  const body = document.querySelector('#orders tbody');
  body.replaceChildren();
  for (const o of orders) {
    const tr = document.createElement('tr');
    tr.append(cell(o.id), cell(o.productName), cell(o.quantity), cell(vnd(o.total)));
    body.append(tr);
  }
}

async function order(productId) {
  const msg = document.querySelector('#message');
  const res = await fetch('/api/orders', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ productId, quantity: 1 }),
  });
  const data = await res.json();
  msg.textContent = res.ok ? `Đã tạo đơn #${data.id}` : `Lỗi: ${data.error}`;
  await loadOrders();
}

loadProducts().then(loadOrders).catch((err) => {
  document.querySelector('#message').textContent = `Không gọi được API: ${err.message}`;
});
