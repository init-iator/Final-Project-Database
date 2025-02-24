import mariadb
import sys
import os
from dotenv import load_dotenv

# Läs in variabler från "Anslutningsuppgifter.env"-filen
load_dotenv("credentials.env")

# Anslutningsuppgifter
DB_CONFIG = {
    "user": os.getenv("DB_USER"),
    "password": os.getenv("DB_PASSWORD"),
    "host": os.getenv("DB_HOST"),
    "database": os.getenv("DB_DATABASE")
}

def connect_db():
    """Skapar en databasanslutning."""
    try:
        conn = mariadb.connect(**DB_CONFIG)
        return conn
    except mariadb.Error as e:
        print(f"Fel vid anslutning till MariaDB: {e}")
        sys.exit(1)

def get_warehouses(conn):
    """Hämtar och listar alla lagerplatser."""
    cursor = conn.cursor()
    cursor.execute("SELECT warehouse_id, city FROM warehouse")
    warehouses = cursor.fetchall()
    for wid, city in warehouses:
        print(f"{wid}: {city}")
    return warehouses

def get_orders_for_warehouse(conn, warehouse_id):
    """Hämtar alla aktiva (ej fullföljda/avbrutna) beställningar för ett lager."""
    cursor = conn.cursor()
    query = """
        SELECT oi.SKU, oi.quantity
        FROM orders_items oi
        JOIN orders o ON oi.order_id = o.order_id
        WHERE o.warehouse_id = %s 
          AND o.status_id = 1
    """
    cursor.execute(query, (warehouse_id,))
    return cursor.fetchall()

def get_inventory(conn, warehouse_id):
    """Hämtar aktuellt lagersaldo för ett lager."""
    cursor = conn.cursor()
    query = """
        SELECT p.SKU, i.quantity 
        FROM inventory i 
        JOIN products p ON i.product_id = p.product_id
        WHERE warehouse_id = %s
    """
    cursor.execute(query, (warehouse_id,))
    return dict(cursor.fetchall())  # Returnerar som {SKU: antal}

def check_order_fulfillment(orders, inventory):
    """Kollar om lagret räcker för att uppfylla alla beställningar."""
    needed = {}

    for sku, qty in orders:
        if inventory.get(sku, 0) < qty:  # Om lagret är för litet
            needed[sku] = qty - inventory.get(sku, 0)

    return needed

def main():
    conn = connect_db()

    # Hämta lager och låt användaren välja
    print("Välj ett lager:")
    warehouses = get_warehouses(conn)
    warehouse_id = int(input("Ange warehouse_id: "))

    # Hämta aktuella beställningar och lagersaldo
    orders = get_orders_for_warehouse(conn, warehouse_id)
    inventory = get_inventory(conn, warehouse_id)

    # Kolla om beställningar kan uppfyllas
    needed = check_order_fulfillment(orders, inventory)

    if not needed:
        print("Alla aktuella beställningar kan fullföljas.")
    else:
        print("Följande produkter saknas för att uppfylla alla beställningar:")
        for sku, qty in needed.items():
            print(f"SKU: {sku}, Saknas: {qty}st")

    conn.close()

if __name__ == "__main__":
    main()
