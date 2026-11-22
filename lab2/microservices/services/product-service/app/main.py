"""Product service: quản lý danh mục sản phẩm (lưu trong bộ nhớ).

Endpoints:
    GET  /health            kiểm tra sống (Kubernetes liveness/readiness)
    GET  /products          danh sách sản phẩm
    GET  /products/{id}     chi tiết 1 sản phẩm
    POST /products          thêm sản phẩm
"""

from __future__ import annotations

import os
from threading import Lock

from fastapi import FastAPI, HTTPException, status
from pydantic import BaseModel, Field

from app import __version__

SERVICE_NAME = "product-service"


class ProductIn(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    price: float = Field(gt=0, description="Giá (VND)")
    stock: int = Field(ge=0)


class Product(ProductIn):
    id: int


class ProductRepository:
    """Kho sản phẩm trong bộ nhớ, an toàn khi nhiều request đồng thời."""

    def __init__(self, seed: list[ProductIn] | None = None) -> None:
        self._items: dict[int, Product] = {}
        self._next_id = 1
        self._lock = Lock()
        for item in seed or []:
            self.add(item)

    def add(self, data: ProductIn) -> Product:
        with self._lock:
            product = Product(id=self._next_id, **data.model_dump())
            self._items[product.id] = product
            self._next_id += 1
            return product

    def list(self) -> list[Product]:
        return list(self._items.values())

    def get(self, product_id: int) -> Product | None:
        return self._items.get(product_id)


DEFAULT_PRODUCTS = [
    ProductIn(name="Bàn phím cơ", price=850000, stock=20),
    ProductIn(name="Chuột không dây", price=320000, stock=50),
    ProductIn(name="Tai nghe Bluetooth", price=1250000, stock=10),
]


def create_app(repo: ProductRepository | None = None) -> FastAPI:
    application = FastAPI(title="Product Service", version=__version__)
    store = repo if repo is not None else ProductRepository(DEFAULT_PRODUCTS)

    @application.get("/health")
    def health() -> dict[str, str]:
        return {
            "status": "ok",
            "service": SERVICE_NAME,
            "version": __version__,
            "pod": os.getenv("HOSTNAME", "local"),
        }

    @application.get("/products", response_model=list[Product])
    def list_products() -> list[Product]:
        return store.list()

    @application.get("/products/{product_id}", response_model=Product)
    def get_product(product_id: int) -> Product:
        product = store.get(product_id)
        if product is None:
            raise HTTPException(status_code=404, detail="Không tìm thấy sản phẩm")
        return product

    @application.post("/products", response_model=Product, status_code=status.HTTP_201_CREATED)
    def create_product(data: ProductIn) -> Product:
        return store.add(data)

    return application


app = create_app()
