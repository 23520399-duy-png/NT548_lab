import pytest
from fastapi.testclient import TestClient

from app.main import ProductIn, ProductRepository, create_app


@pytest.fixture()
def client() -> TestClient:
    repo = ProductRepository([ProductIn(name="Laptop", price=15000000, stock=5)])
    return TestClient(create_app(repo))


def test_health(client: TestClient) -> None:
    res = client.get("/health")
    assert res.status_code == 200
    body = res.json()
    assert body["status"] == "ok"
    assert body["service"] == "product-service"


def test_list_products(client: TestClient) -> None:
    res = client.get("/products")
    assert res.status_code == 200
    assert res.json() == [{"id": 1, "name": "Laptop", "price": 15000000.0, "stock": 5}]


def test_get_product(client: TestClient) -> None:
    res = client.get("/products/1")
    assert res.status_code == 200
    assert res.json()["name"] == "Laptop"


def test_get_product_not_found(client: TestClient) -> None:
    res = client.get("/products/999")
    assert res.status_code == 404


def test_create_product(client: TestClient) -> None:
    res = client.post("/products", json={"name": "Màn hình", "price": 3500000, "stock": 3})
    assert res.status_code == 201
    assert res.json()["id"] == 2
    assert len(client.get("/products").json()) == 2


@pytest.mark.parametrize(
    "payload",
    [
        {"name": "", "price": 1000, "stock": 1},
        {"name": "A", "price": 0, "stock": 1},
        {"name": "A", "price": 1000, "stock": -1},
    ],
)
def test_create_product_invalid(client: TestClient, payload: dict) -> None:
    res = client.post("/products", json=payload)
    assert res.status_code == 422


def test_default_app_has_seed_data() -> None:
    res = TestClient(create_app()).get("/products")
    assert len(res.json()) == 3
