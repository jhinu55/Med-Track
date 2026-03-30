#!/usr/bin/env python3
"""
Seed script for MedTrack MySQL database.

What it does:
1) Clears existing transactional/master data.
2) Inserts 1 Admin actor.
3) Inserts 3 Manufacturers.
4) Inserts 10 Pharmacies with realistic city GPS coordinates.
5) Inserts 10 Medicines.
6) Inserts 500 Batches (80% valid, 20% expired).
7) Distributes batches into INVENTORY.
8) Creates TRANSFER_LOG history from Manufacturer -> Pharmacy.

It also creates deterministic test hashes for Postman:
- VALID_TEST_QR_HASH
- EXPIRED_TEST_QR_HASH
"""

from __future__ import annotations

import hashlib
import os
import random
import uuid
from datetime import date, datetime, time, timedelta

import mysql.connector
from faker import Faker

DB_HOST = os.getenv("DB_HOST", os.getenv("MYSQL_HOST", "localhost"))
DB_PORT = int(os.getenv("DB_PORT", os.getenv("MYSQL_PORT", "3307")))
DB_USER = os.getenv("DB_USER", os.getenv("MYSQL_USER", "medtrack"))
DB_PASSWORD = os.getenv("DB_PASSWORD", os.getenv("MYSQL_PASSWORD", "medtrack123"))
DB_NAME = os.getenv("DB_NAME", os.getenv("MYSQL_DB", "PharmaGuard"))

TOTAL_BATCHES = 500
VALID_RATIO = 0.80

VALID_TEST_QR_HASH = "aee0123f3d9add033107ec2d0aba9dff5c2020597aa00452589b89051ec34e18"
EXPIRED_TEST_QR_HASH = "de5ae70aea72411679de10f2d69044decf10edda05d4934127dcc17c85b18813"


def sha256_hex(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def random_qr_hash(seed_text: str) -> str:
    return sha256_hex(f"{seed_text}-{uuid.uuid4().hex}-{random.random()}")


def connect():
    return mysql.connector.connect(
        host=DB_HOST,
        port=DB_PORT,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME,
    )


def clear_existing_data(cur) -> None:
    tables = [
        "ALERT",
        "SCAN_LOG",
        "SALE_TRANSACTION",
        "TRANSFER_LOG",
        "INVENTORY",
        "BATCH",
        "MEDICINE",
        "MANUFACTURER",
        "PHARMACY",
        "ADMIN",
        "ACTOR",
    ]

    cur.execute("SET FOREIGN_KEY_CHECKS = 0")
    for table in tables:
        cur.execute(f"TRUNCATE TABLE {table}")
    cur.execute("SET FOREIGN_KEY_CHECKS = 1")


def insert_actor(cur, username: str, email: str, role_type: str) -> int:
    password_hash = sha256_hex(f"{username}@MedTrack#2026")
    cur.execute(
        """
        INSERT INTO ACTOR (username, password_hash, email, role_type)
        VALUES (%s, %s, %s, %s)
        """,
        (username, password_hash, email, role_type),
    )
    return int(cur.lastrowid)


def seed_actors(cur, fake: Faker):
    # 1 Admin
    admin_id = insert_actor(
        cur=cur,
        username="admin_medtrack",
        email="admin@medtrack.local",
        role_type="Admin",
    )
    cur.execute(
        "INSERT INTO ADMIN (actor_id, security_clearance_level) VALUES (%s, %s)",
        (admin_id, 5),
    )

    # 3 Manufacturers
    manufacturer_companies = [
        "Sun Pharma Industries",
        "Cipla Therapeutics",
        "Dr Reddy's Laboratories",
    ]
    manufacturers = []
    for idx, company in enumerate(manufacturer_companies, start=1):
        username = f"mfg_{idx}_{uuid.uuid4().hex[:6]}"
        actor_id = insert_actor(
            cur=cur,
            username=username,
            email=f"{username}@medtrack.local",
            role_type="Manufacturer",
        )
        license_no = f"MFG-LIC-{fake.random_number(digits=6, fix_len=True)}"
        production_capacity = random.randint(50000, 250000)
        cur.execute(
            """
            INSERT INTO MANUFACTURER (actor_id, license_no, production_capacity)
            VALUES (%s, %s, %s)
            """,
            (actor_id, license_no, production_capacity),
        )
        manufacturers.append(
            {"actor_id": actor_id, "company_name": company, "license_no": license_no}
        )

    # 10 Pharmacies with city-distributed GPS
    city_coordinates = [
        ("Mumbai", 19.0760, 72.8777),
        ("Delhi", 28.6139, 77.2090),
        ("Bengaluru", 12.9716, 77.5946),
        ("Hyderabad", 17.3850, 78.4867),
        ("Chennai", 13.0827, 80.2707),
        ("Kolkata", 22.5726, 88.3639),
        ("Pune", 18.5204, 73.8567),
        ("Ahmedabad", 23.0225, 72.5714),
        ("Jaipur", 26.9124, 75.7873),
        ("Lucknow", 26.8467, 80.9462),
    ]
    pharmacies = []
    for idx, (city, lat, lng) in enumerate(city_coordinates, start=1):
        username = f"pharmacy_{city.lower()}_{idx}"
        actor_id = insert_actor(
            cur=cur,
            username=username,
            email=f"{username}@medtrack.local",
            role_type="Pharmacy",
        )
        pharmacy_license = f"PHR-{city[:3].upper()}-{fake.random_number(digits=6, fix_len=True)}"
        lat_jittered = round(lat + random.uniform(-0.06, 0.06), 8)
        lng_jittered = round(lng + random.uniform(-0.06, 0.06), 8)

        cur.execute(
            """
            INSERT INTO PHARMACY (actor_id, pharmacy_license, gps_lat, gps_long)
            VALUES (%s, %s, %s, %s)
            """,
            (actor_id, pharmacy_license, lat_jittered, lng_jittered),
        )
        pharmacies.append(
            {
                "actor_id": actor_id,
                "city": city,
                "gps_lat": lat_jittered,
                "gps_long": lng_jittered,
                "license": pharmacy_license,
            }
        )

    return admin_id, manufacturers, pharmacies


def seed_medicines(cur):
    medicines = [
        ("Paracetamol", "Calpol", 18.50),
        ("Amoxicillin", "Moxikind", 145.00),
        ("Azithromycin", "Azithral", 120.00),
        ("Metformin", "Glycomet", 35.00),
        ("Atorvastatin", "Atorlip", 85.00),
        ("Pantoprazole", "Pantocid", 52.00),
        ("Cetirizine", "Cetzine", 20.00),
        ("Omeprazole", "Omez", 44.00),
        ("Losartan", "Losar", 110.00),
        ("Levothyroxine", "Thyronorm", 130.00),
    ]

    cur.executemany(
        """
        INSERT INTO MEDICINE (generic_name, brand_name, base_price)
        VALUES (%s, %s, %s)
        """,
        medicines,
    )

    cur.execute("SELECT medicine_id FROM MEDICINE ORDER BY medicine_id")
    medicine_ids = [int(row[0]) for row in cur.fetchall()]
    return medicine_ids


def random_datetime_between(d1: date, d2: date) -> datetime:
    if d2 < d1:
        d1, d2 = d2, d1
    days = (d2 - d1).days
    chosen = d1 + timedelta(days=random.randint(0, max(days, 0)))
    return datetime.combine(chosen, time(hour=random.randint(7, 20), minute=random.randint(0, 59)))


def build_batch_plan(medicine_ids, manufacturers, pharmacies):
    today = date.today()
    valid_target = int(TOTAL_BATCHES * VALID_RATIO)  # 400
    expired_target = TOTAL_BATCHES - valid_target  # 100

    test_pharmacy_id = pharmacies[0]["actor_id"]
    seen_hashes = {VALID_TEST_QR_HASH, EXPIRED_TEST_QR_HASH}

    plan = []

    def add_plan_item(
        qr_hash: str,
        is_expired: bool,
        manufacturer_id: int,
        pharmacy_id: int,
        quantity: int,
    ) -> None:
        medicine_id = random.choice(medicine_ids)
        if is_expired:
            expiry = today - timedelta(days=random.randint(1, 540))
            mfg = expiry - timedelta(days=random.randint(120, 900))
        else:
            expiry = today + timedelta(days=random.randint(45, 900))
            mfg = expiry - timedelta(days=random.randint(120, 800))

        transfer_start = random_datetime_between(mfg + timedelta(days=1), min(today, mfg + timedelta(days=120)))
        transfer_received = transfer_start + timedelta(hours=random.randint(4, 120))
        now_dt = datetime.now()
        if transfer_received > now_dt:
            transfer_received = now_dt

        plan.append(
            {
                "medicine_id": medicine_id,
                "qr_hash": qr_hash,
                "mfg_date": mfg,
                "expiry_date": expiry,
                "manufacturer_id": manufacturer_id,
                "pharmacy_id": pharmacy_id,
                "quantity": quantity,
                "transfer_start": transfer_start,
                "transfer_received": transfer_received,
            }
        )

    # Deterministic test rows
    add_plan_item(
        qr_hash=VALID_TEST_QR_HASH,
        is_expired=False,
        manufacturer_id=manufacturers[0]["actor_id"],
        pharmacy_id=test_pharmacy_id,
        quantity=150,
    )
    add_plan_item(
        qr_hash=EXPIRED_TEST_QR_HASH,
        is_expired=True,
        manufacturer_id=manufacturers[1]["actor_id"],
        pharmacy_id=test_pharmacy_id,
        quantity=150,
    )

    remaining_valid = valid_target - 1
    remaining_expired = expired_target - 1

    for i in range(remaining_valid):
        while True:
            qr = random_qr_hash(f"valid-{i}")
            if qr not in seen_hashes:
                seen_hashes.add(qr)
                break
        add_plan_item(
            qr_hash=qr,
            is_expired=False,
            manufacturer_id=random.choice(manufacturers)["actor_id"],
            pharmacy_id=random.choice(pharmacies)["actor_id"],
            quantity=random.randint(20, 250),
        )

    for i in range(remaining_expired):
        while True:
            qr = random_qr_hash(f"expired-{i}")
            if qr not in seen_hashes:
                seen_hashes.add(qr)
                break
        add_plan_item(
            qr_hash=qr,
            is_expired=True,
            manufacturer_id=random.choice(manufacturers)["actor_id"],
            pharmacy_id=random.choice(pharmacies)["actor_id"],
            quantity=random.randint(20, 200),
        )

    random.shuffle(plan)
    return plan, test_pharmacy_id


def insert_batches_inventory_transfer(cur, plan):
    # Insert BATCH rows (current owner is pharmacy, matching inventory ownership)
    batch_rows = [
        (
            item["medicine_id"],
            item["qr_hash"],
            item["mfg_date"],
            item["expiry_date"],
            item["pharmacy_id"],
        )
        for item in plan
    ]
    cur.executemany(
        """
        INSERT INTO BATCH (medicine_id, qr_code_hash, mfg_date, expiry_date, current_owner_id)
        VALUES (%s, %s, %s, %s, %s)
        """,
        batch_rows,
    )

    # Map qr_hash -> batch_id
    cur.execute("SELECT batch_id, qr_code_hash FROM BATCH")
    hash_to_batch_id = {row[1]: int(row[0]) for row in cur.fetchall()}

    inventory_rows = []
    transfer_rows = []

    for item in plan:
        batch_id = hash_to_batch_id[item["qr_hash"]]
        inventory_rows.append((item["pharmacy_id"], batch_id, item["quantity"]))

        # History: In-Transit then Received (Manufacturer -> Pharmacy)
        transfer_rows.append(
            (
                batch_id,
                item["manufacturer_id"],
                item["pharmacy_id"],
                item["transfer_start"],
                "In-Transit",
            )
        )
        transfer_rows.append(
            (
                batch_id,
                item["manufacturer_id"],
                item["pharmacy_id"],
                item["transfer_received"],
                "Received",
            )
        )

    cur.executemany(
        """
        INSERT INTO INVENTORY (pharmacy_id, batch_id, quantity_on_hand)
        VALUES (%s, %s, %s)
        """,
        inventory_rows,
    )

    cur.executemany(
        """
        INSERT INTO TRANSFER_LOG (batch_id, sender_id, receiver_id, transfer_date, status)
        VALUES (%s, %s, %s, %s, %s)
        """,
        transfer_rows,
    )


def main():
    random.seed(42)
    fake = Faker("en_IN")
    Faker.seed(42)

    conn = connect()
    cur = conn.cursor()

    try:
        clear_existing_data(cur)
        admin_id, manufacturers, pharmacies = seed_actors(cur, fake)
        medicine_ids = seed_medicines(cur)
        plan, test_pharmacy_id = build_batch_plan(medicine_ids, manufacturers, pharmacies)
        insert_batches_inventory_transfer(cur, plan)

        conn.commit()

        print("Seeding completed successfully.")
        print(f"Admin actor_id: {admin_id}")
        print(f"Manufacturers inserted: {len(manufacturers)}")
        print(f"Pharmacies inserted: {len(pharmacies)}")
        print(f"Medicines inserted: {len(medicine_ids)}")
        print(f"Batches inserted: {len(plan)}")
        print(f"Transfer log rows inserted: {len(plan) * 2}")
        print("--- Test values for Postman ---")
        print(f"test_pharmacy_id={test_pharmacy_id}")
        print(f"valid_qr_hash={VALID_TEST_QR_HASH}")
        print(f"expired_qr_hash={EXPIRED_TEST_QR_HASH}")

    except Exception:
        conn.rollback()
        raise
    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    main()
