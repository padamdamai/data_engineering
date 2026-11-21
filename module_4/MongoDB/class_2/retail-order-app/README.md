# Retail Order Management

Retail Order Management is a small full-stack application that captures customer grocery orders and stores them in MongoDB Atlas. It provides an order-entry interface, server-side price calculation, operational status updates, and MongoDB documents suitable for downstream data processing.

## Application flow

```text
Web browser  →  FastAPI application  →  MongoDB Atlas
```

The browser never connects to MongoDB directly. It calls HTTP endpoints in `app.py`; the application validates each request, reads current product prices from MongoDB, calculates the order total, and then writes the completed document.

## Project structure

```text
retail-order-app/
├── app.py              # API, validation, pricing, and MongoDB operations
├── seed_data.py        # Fixed product catalog
├── requirements.txt    # Python packages
├── README.md           # Setup and operating instructions
└── static/
    ├── index.html      # Order entry and tracking interface
    ├── styles.css      # Page styling
    └── app.js          # Browser interactions and API calls
```

## Prerequisites

- Python 3.9 or later
- A MongoDB Atlas cluster
- An Atlas database user with read and write access
- Your current IP address added to the Atlas IP access list

## 1. Prepare MongoDB Atlas

1. Open MongoDB Atlas and select the required project.
2. Open **Database Access** and create a database user if one does not exist.
3. Open **Network Access** and add your current public IP address.
4. Open **Database**, select **Connect**, and choose **Drivers**.
5. Select Python as the driver and copy the connection string.
6. Replace `<username>`, `<password>`, and `<cluster-url>` with the actual values.

If the password contains a reserved URL character such as `@`, `/`, `:` or `#`, encode it before placing it in the connection string.

## 2. Configure the application

Open both `app.py` and `seed_data.py`. Near the top of each file, replace this placeholder:

```python
MONGODB_URI = "mongodb+srv://<username>:<password>@<cluster-url>/?retryWrites=true&w=majority"
```

Use the same connection string in both files. The application uses this database name:

```python
DATABASE_NAME = "retail_order_management"
```

The connection string is stored directly in the two Python files to keep local execution easy to follow. Treat the configured files as private because the URI contains credentials.

## 3. Install the Python packages

From the `retail-order-app` directory, create and activate a virtual environment:

### macOS or Linux

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
```

### Windows PowerShell

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
```

## 4. Load the product catalog

Run the seed script once:

```bash
python seed_data.py
```

Expected result:

```text
Product catalog is ready: 8 active products
```

The script uses `sku` as a unique business key. Running it again updates the existing catalog instead of creating duplicate products.

## 5. Start the application

```bash
uvicorn app:app --reload
```

Open [http://127.0.0.1:8000](http://127.0.0.1:8000). The header should display **Atlas connected**. Interactive API documentation is available at [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs).

Do not use Chrome's **Open File** option for the main workflow. Opening `static/index.html` directly can display the page, but it does not start FastAPI, so product loading, Atlas health checks, order creation, and status updates will not work. Always use `http://127.0.0.1:8000` after starting `uvicorn`.

Stop the application with `Ctrl+C`.

## Using the application

### Create an order

1. Enter a customer name, ten-digit Indian mobile number, and email address.
2. Enter the delivery address, city, and six-digit postal code.
3. Add one or more products. A product quantity can be between 1 and 10.
4. Choose a delivery slot and payment method.
5. Review the displayed total and select **Place order**.

The browser total is a preview. `app.py` fetches product prices again and calculates the authoritative total before inserting the order.

Delivery costs ₹40 for an order below ₹500 and is free for an order of ₹500 or more.

### Update fulfillment status

Open **Orders** in the navigation bar. Each order offers only valid next statuses:

```text
PLACED → CONFIRMED → PACKING → READY → DISPATCHED → DELIVERED
```

An order may be cancelled before dispatch. Delivered and cancelled orders cannot be changed further. Every change updates the current `status` and appends an entry to `status_history`.

## MongoDB data model

The database contains two collections.

### `products`

```javascript
{
  _id: ObjectId("..."),
  sku: "GRC-RCE-005",
  name: "India Gate Basmati Rice",
  category: "Staples",
  unit: "5 kg bag",
  price: 725.0,
  active: true
}
```

### `orders`

```javascript
{
  _id: ObjectId("..."),
  customer: {
    name: "Aarav Mehta",
    phone: "9876543210",
    email: "aarav@example.com"
  },
  delivery_address: {
    address_line: "42, Lakeview Road, Indiranagar",
    city: "Bengaluru",
    postal_code: "560038"
  },
  items: [
    {
      product_id: ObjectId("..."),
      sku: "GRC-RCE-005",
      name: "India Gate Basmati Rice",
      category: "Staples",
      unit: "5 kg bag",
      unit_price: 725.0,
      quantity: 1,
      line_total: 725.0
    }
  ],
  pricing: {
    subtotal: 725.0,
    delivery_fee: 0.0,
    grand_total: 725.0,
    currency: "INR"
  },
  payment_method: "UPI",
  delivery_slot: "09:00 AM - 12:00 PM",
  status: "PLACED",
  status_history: [
    { status: "PLACED", changed_at: ISODate("...") }
  ],
  created_at: ISODate("..."),
  updated_at: ISODate("...")
}
```

Product information is copied into each order item intentionally. It preserves the product name, unit, and price that applied when the customer placed the order, even if the catalog changes later.

## API reference

| Method | Endpoint | Purpose |
|---|---|---|
| `GET` | `/api/health` | Verify the Atlas connection |
| `GET` | `/api/products` | Return active catalog products |
| `POST` | `/api/orders` | Validate and create an order |
| `GET` | `/api/orders` | Return the 50 most recent orders |
| `PATCH` | `/api/orders/{order_id}/status` | Apply a valid status transition |

FastAPI validates request fields automatically. Product identifiers and prices are checked against MongoDB during order creation.

## Verification checklist

After placing an order:

1. Confirm that the UI displays the new order under **Orders**.
2. In Atlas, open **Browse Collections**.
3. Select the `retail_order_management` database and `orders` collection.
4. Confirm the customer, items, pricing, and `PLACED` status.
5. Update the status in the UI and refresh the Atlas document.
6. Confirm that `status` changed and `status_history` gained another entry.

## Troubleshooting

### Atlas unavailable

- Confirm that the URI was replaced in both Python files.
- Confirm that the database username and password are correct.
- Add the current public IP address to the Atlas IP access list.
- Wait a few minutes if the free cluster is resuming from an idle state.

### Products are not displayed

Run `python seed_data.py`, then refresh the browser. Check that the script and application use the same URI and database name.

### Authentication failed

Use the Atlas database user credentials, not the email and password used to sign in to the Atlas website. Encode reserved characters in the database password.

### Port 8000 is already in use

Start the server on another port:

```bash
uvicorn app:app --reload --port 8001
```

Then open `http://127.0.0.1:8001`.

### Reset order data

To start with an empty operational collection, open Atlas **Browse Collections**, select `retail_order_management.orders`, and delete its documents. Keep the `products` collection so the catalog remains available.
