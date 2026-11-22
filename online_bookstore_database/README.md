# Online Bookstore Database Management System

## Project Overview
The **Online Bookstore Database Management System** is a MySQL-based relational database project designed to manage bookstore operations. It stores book inventory, customer records, orders, order items, and admin roles. The project demonstrates database design, data integrity, order processing, stock management, and SQL-based analysis.

## Objectives
- Organize bookstore data in relational tables.
- Maintain relationships using primary and foreign keys.
- Track customer orders and order items.
- Update inventory when items are ordered and prevent insufficient-stock orders.
- Generate sales, order, and customer summaries.
- Demonstrate reusable SQL objects and basic database optimization.

## Technologies
- MySQL 8.0+
- SQL
- MySQL Workbench (recommended)

## Database Schema
The database contains five tables:

| Table | Description |
|---|---|
| `Books` | Book title, author, price, stock, category, and publication date |
| `Customers` | Customer name, email, phone, address, and registration timestamp |
| `Orders` | Customer order date, total, and status |
| `Order_Items` | Books, quantity, unit price, and line subtotal per order |
| `Admins` | Admin username, password hash placeholder, and role |

### Relationships
- One customer can have many orders.
- One order can contain multiple order items.
- One book can be referenced by multiple order items.
- `Order_Items` links orders and books.

## Features
- Book and customer data storage
- Order and order-item management
- Inventory validation and stock reduction with triggers
- Automatic line-subtotal and order-total calculations
- Stored procedure for processing a single-book order
- 10% discount calculation function
- Order summary view
- Sales and customer analysis queries
- Indexes for common lookups
- Query plan inspection with `EXPLAIN`
- Optional database user and privilege examples

## SQL Concepts Demonstrated
`CREATE DATABASE`, `CREATE TABLE`, `INSERT`, `SELECT`, `UPDATE`, `JOIN`, `GROUP BY`, `ORDER BY`, aggregate functions, primary keys, foreign keys, constraints, indexes, stored procedures, triggers, functions, views, transactions, `EXPLAIN`, `GRANT`, and `REVOKE`.

## Setup and Execution
1. Install MySQL 8.0 or later and open MySQL Workbench (or another MySQL client).
2. Download or clone this repository.
3. Open `online_bookstore.sql`.
4. Execute the script from top to bottom.
   - **Note:** The script begins with `DROP DATABASE IF EXISTS Bookstore;` so it will delete and recreate a database named `Bookstore`. Do not run it against a database containing data you need.
5. Run the sample queries in the script to inspect books, orders, sales, and customer summaries.

## Example Procedure
The script creates a procedure called `ProcessOrder`.

```sql
CALL ProcessOrder(1, 2, 2);
```

This creates an order for customer ID 1 with two copies of book ID 2, checks stock, and calculates the order total.

## Example Queries
### Best-selling books
```sql
SELECT
    b.title,
    SUM(oi.quantity) AS total_sold
FROM Books b
JOIN Order_Items oi ON oi.book_id = b.book_id
JOIN Orders o ON o.order_id = oi.order_id
WHERE o.status <> 'Cancelled'
GROUP BY b.book_id, b.title
ORDER BY total_sold DESC;
```

### Customer order summary
```sql
SELECT * FROM OrderSummary;
```

### Calculate 10% discount
```sql
SELECT CalculateDiscount(1000) AS discount_amount;
```

## Project Structure
```text
online-bookstore-database/
├── online_bookstore.sql
└── README.md
```

## Notes / Limitations
- This is a database-focused learning project; it does not include a frontend, payment gateway, or web application.
- Admin password values in the sample data are placeholders, not usable credentials.
- User creation and privilege commands are commented out by default. Uncomment and change the passwords only in a local test environment; never commit real credentials.
- Sample records are for demonstration.
- In this learning version, order cancellation does not automatically restore inventory. A production system would need cancellation logic, stock-restoration rules, and safeguards against restoring stock more than once.
- For a production system, order creation should validate the customer, book, quantity, and stock in a single transaction. The SQL procedure is intended as a learning demonstration.

## Author
**Cathrin Prasalya R.**

## License
This project is available for educational and portfolio demonstration purposes.
