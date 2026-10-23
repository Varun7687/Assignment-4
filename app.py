import os
from datetime import datetime

import pymysql
from flask import Flask, flash, redirect, render_template, request, url_for

app = Flask(__name__)
app.config["SECRET_KEY"] = os.environ.get("APP_SECRET_KEY", "assignment-4-change-me")


def db_config():
    return {
        "host": os.environ["DB_HOST"],
        "port": int(os.environ.get("DB_PORT", "3306")),
        "user": os.environ["DB_USER"],
        "password": os.environ["DB_PASSWORD"],
        "database": os.environ.get("DB_NAME", "inventory"),
        "connect_timeout": 5,
        "read_timeout": 10,
        "write_timeout": 10,
        "cursorclass": pymysql.cursors.DictCursor,
        "autocommit": True,
    }


def get_connection():
    return pymysql.connect(**db_config())


@app.get("/health")
def health():
    try:
        with get_connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1 AS ok")
                cursor.fetchone()
        return {"status": "ok"}, 200
    except Exception:
        return {"status": "unavailable"}, 503


@app.get("/")
def index():
    with get_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT id, item_name, sku, quantity, warehouse_location, last_updated
                FROM items
                ORDER BY id
                """
            )
            items = cursor.fetchall()
    return render_template("index.html", items=items)


@app.post("/items")
def add_item():
    item_name = request.form.get("item_name", "").strip()
    sku = request.form.get("sku", "").strip()
    warehouse_location = request.form.get("warehouse_location", "").strip()
    quantity_text = request.form.get("quantity", "").strip()

    errors = []
    if not item_name:
        errors.append("Item name is required.")
    if not sku:
        errors.append("SKU is required.")
    if not warehouse_location:
        errors.append("Warehouse location is required.")
    try:
        quantity = int(quantity_text)
        if quantity < 0:
            raise ValueError
    except ValueError:
        errors.append("Quantity must be a non-negative whole number.")
        quantity = 0

    if errors:
        for error in errors:
            flash(error, "error")
        return redirect(url_for("index"))

    try:
        with get_connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    INSERT INTO items (item_name, sku, quantity, warehouse_location)
                    VALUES (%s, %s, %s, %s)
                    """,
                    (item_name, sku, quantity, warehouse_location),
                )
        flash(f"Added {item_name} ({sku}).", "success")
    except pymysql.err.IntegrityError:
        flash("That SKU already exists. Use a unique SKU.", "error")
    except Exception:
        app.logger.exception("Inventory insert failed")
        flash("The item could not be added. Check the application log.", "error")

    return redirect(url_for("index"))


@app.template_filter("display_time")
def display_time(value):
    if isinstance(value, datetime):
        return value.strftime("%Y-%m-%d %H:%M:%S")
    return value


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
