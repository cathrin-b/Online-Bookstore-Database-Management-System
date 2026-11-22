-- ============================================================
-- PROJECT: Online Bookstore Database Management System
-- DATABASE: MySQL 8.0+
-- ============================================================

-- 1. CREATE DATABASE
DROP DATABASE IF EXISTS Bookstore;
CREATE DATABASE Bookstore;
USE Bookstore;

-- 2. TABLES

CREATE TABLE Books (
    book_id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    author VARCHAR(255) NOT NULL,
    price DECIMAL(10,2) NOT NULL CHECK (price >= 0),
    stock INT NOT NULL DEFAULT 0 CHECK (stock >= 0),
    category VARCHAR(100),
    published_date DATE
);

CREATE TABLE Customers (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    address TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE Orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total_amount DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
    status ENUM('Pending', 'Completed', 'Cancelled') DEFAULT 'Pending',
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id) REFERENCES Customers(customer_id)
        ON DELETE RESTRICT
);

CREATE TABLE Order_Items (
    order_item_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    book_id INT NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10,2) NOT NULL CHECK (unit_price >= 0),
    subtotal DECIMAL(10,2) NOT NULL CHECK (subtotal >= 0),
    CONSTRAINT fk_order_items_order
        FOREIGN KEY (order_id) REFERENCES Orders(order_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_order_items_book
        FOREIGN KEY (book_id) REFERENCES Books(book_id)
        ON DELETE RESTRICT
);

CREATE TABLE Admins (
    admin_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role ENUM('Manager', 'Staff') DEFAULT 'Staff'
);

-- 3. SAMPLE DATA

INSERT INTO Books (title, author, price, stock, category, published_date) VALUES
('The Great Gatsby', 'F. Scott Fitzgerald', 10.99, 50, 'Fiction', '1925-04-10'),
('1984', 'George Orwell', 8.99, 40, 'Dystopian', '1949-06-08'),
('To Kill a Mockingbird', 'Harper Lee', 12.50, 30, 'Classic', '1960-07-11'),
('The Catcher in the Rye', 'J. D. Salinger', 9.99, 20, 'Novel', '1951-07-16'),
('Moby Dick', 'Herman Melville', 15.75, 25, 'Adventure', '1851-10-18');

INSERT INTO Customers (name, email, phone, address) VALUES
('Alice Johnson', 'alice@example.com', '1234567890', '123 Main Street'),
('Bob Smith', 'bob@example.com', '0987654321', '456 Elm Street'),
('Charlie Brown', 'charlie@example.com', '1122334455', '789 Pine Street'),
('David Wilson', 'david@example.com', '2233445566', '101 Oak Street'),
('Eve Adams', 'eve@example.com', '3344556677', '202 Birch Street');

INSERT INTO Admins (username, password_hash, role) VALUES
('admin1', 'REPLACE_WITH_SECURE_HASH', 'Manager'),
('staff1', 'REPLACE_WITH_SECURE_HASH', 'Staff'),
('admin2', 'REPLACE_WITH_SECURE_HASH', 'Manager'),
('staff2', 'REPLACE_WITH_SECURE_HASH', 'Staff'),
('staff3', 'REPLACE_WITH_SECURE_HASH', 'Staff');

-- 4. INDEXES
CREATE INDEX idx_customers_email ON Customers(email);
CREATE INDEX idx_orders_customer_id ON Orders(customer_id);
CREATE INDEX idx_order_items_order_id ON Order_Items(order_id);
CREATE INDEX idx_order_items_book_id ON Order_Items(book_id);
CREATE INDEX idx_books_category ON Books(category);

-- 5. TRIGGER: Validate stock and decrease stock when an order item is added
DELIMITER //

CREATE TRIGGER trg_order_items_before_insert
BEFORE INSERT ON Order_Items
FOR EACH ROW
BEGIN
    DECLARE current_stock INT;

    IF NEW.quantity <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Quantity must be greater than zero';
    END IF;

    SELECT stock INTO current_stock
    FROM Books
    WHERE book_id = NEW.book_id
    FOR UPDATE;

    IF current_stock IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Book does not exist';
    ELSEIF current_stock < NEW.quantity THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Insufficient stock';
    END IF;

    UPDATE Books
    SET stock = stock - NEW.quantity
    WHERE book_id = NEW.book_id;
END //

-- 6. TRIGGER: Calculate line subtotal from stored unit price and quantity
CREATE TRIGGER trg_order_items_before_insert_price
BEFORE INSERT ON Order_Items
FOR EACH ROW
BEGIN
    SET NEW.subtotal = NEW.unit_price * NEW.quantity;
END //

-- 7. TRIGGER: Recalculate order total after inserting an item
CREATE TRIGGER trg_order_items_after_insert
AFTER INSERT ON Order_Items
FOR EACH ROW
BEGIN
    UPDATE Orders
    SET total_amount = (
        SELECT COALESCE(SUM(subtotal), 0)
        FROM Order_Items
        WHERE order_id = NEW.order_id
    )
    WHERE order_id = NEW.order_id;
END //

-- 8. STORED PROCEDURE: Process an order for one book
CREATE PROCEDURE ProcessOrder(
    IN p_customer_id INT,
    IN p_book_id INT,
    IN p_quantity INT
)
BEGIN
    DECLARE v_price DECIMAL(10,2);
    DECLARE v_order_id INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_quantity <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Quantity must be greater than zero';
    END IF;

    START TRANSACTION;

    SELECT price INTO v_price
    FROM Books
    WHERE book_id = p_book_id;

    IF v_price IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Book does not exist';
    END IF;

    INSERT INTO Orders (customer_id, total_amount, status)
    VALUES (p_customer_id, 0, 'Pending');

    SET v_order_id = LAST_INSERT_ID();

    INSERT INTO Order_Items (order_id, book_id, quantity, unit_price, subtotal)
    VALUES (v_order_id, p_book_id, p_quantity, v_price, v_price * p_quantity);

    COMMIT;
    SELECT v_order_id AS created_order_id, v_price * p_quantity AS order_total;
END //

-- 9. FUNCTION: Calculate 10% discount
CREATE FUNCTION CalculateDiscount(p_amount DECIMAL(10,2))
RETURNS DECIMAL(10,2)
DETERMINISTIC
NO SQL
BEGIN
    RETURN ROUND(p_amount * 0.10, 2);
END //

DELIMITER ;

-- 10. SAMPLE ORDERS USING PROCEDURE
CALL ProcessOrder(1, 2, 2); -- 2 copies of 1984
CALL ProcessOrder(2, 5, 1); -- 1 copy of Moby Dick
CALL ProcessOrder(3, 4, 1); -- 1 copy of The Catcher in the Rye
CALL ProcessOrder(4, 1, 2); -- 2 copies of The Great Gatsby
CALL ProcessOrder(5, 3, 1); -- 1 copy of To Kill a Mockingbird

-- Update sample statuses
UPDATE Orders SET status = 'Completed' WHERE order_id IN (1, 4);
UPDATE Orders SET status = 'Cancelled' WHERE order_id = 3;

-- 11. ANALYTICAL QUERIES

-- A. View all books
SELECT * FROM Books ORDER BY title;

-- B. Find books with low stock (threshold: 10)
SELECT book_id, title, stock
FROM Books
WHERE stock <= 10
ORDER BY stock ASC;

-- C. Customer orders with order totals
SELECT
    c.name AS customer_name,
    o.order_id,
    o.order_date,
    o.total_amount,
    o.status
FROM Customers c
JOIN Orders o ON o.customer_id = c.customer_id
ORDER BY o.order_date DESC;

-- D. Best-selling books
SELECT
    b.book_id,
    b.title,
    b.category,
    SUM(oi.quantity) AS total_sold
FROM Books b
JOIN Order_Items oi ON oi.book_id = b.book_id
JOIN Orders o ON o.order_id = oi.order_id
WHERE o.status <> 'Cancelled'
GROUP BY b.book_id, b.title, b.category
ORDER BY total_sold DESC, b.title;

-- E. Sales by category
SELECT
    b.category,
    SUM(oi.quantity) AS books_sold,
    SUM(oi.subtotal) AS revenue
FROM Books b
JOIN Order_Items oi ON oi.book_id = b.book_id
JOIN Orders o ON o.order_id = oi.order_id
WHERE o.status <> 'Cancelled'
GROUP BY b.category
ORDER BY revenue DESC;

-- F. Revenue by order status
SELECT status, COUNT(*) AS order_count, SUM(total_amount) AS total_amount
FROM Orders
GROUP BY status;

-- G. Customer spending summary
SELECT
    c.customer_id,
    c.name,
    COUNT(DISTINCT o.order_id) AS number_of_orders,
    COALESCE(SUM(CASE WHEN o.status <> 'Cancelled' THEN o.total_amount ELSE 0 END), 0) AS total_spent
FROM Customers c
LEFT JOIN Orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.name
ORDER BY total_spent DESC;

-- H. Books with their order item details
SELECT
    b.title,
    oi.order_id,
    oi.quantity,
    oi.unit_price,
    oi.subtotal
FROM Books b
JOIN Order_Items oi ON oi.book_id = b.book_id
ORDER BY b.title, oi.order_id;

-- 12. VIEW: Order summary
CREATE VIEW OrderSummary AS
SELECT
    o.order_id,
    c.name AS customer_name,
    o.order_date,
    o.total_amount,
    o.status
FROM Orders o
JOIN Customers c ON c.customer_id = o.customer_id;

-- View the summary
SELECT * FROM OrderSummary;

-- 13. FUNCTION TEST
SELECT CalculateDiscount(1000.00) AS discount_amount;

-- 14. TRANSACTION EXAMPLE
-- Example: update stock with a transaction and rollback if invalid.
-- Run this block as a stored procedure or execute the statements individually
-- with application-side validation. MySQL does not support standalone IF blocks.

START TRANSACTION;

UPDATE Books
SET stock = stock - 1
WHERE book_id = 1 AND stock >= 1;

-- Verify affected rows and stock in your client/application.
-- If the update was valid:
COMMIT;

-- If validation fails, use ROLLBACK instead of COMMIT.

-- 15. QUERY PLAN / OPTIMIZATION
EXPLAIN
SELECT *
FROM Orders
WHERE customer_id = 5;

-- 16. USER PRIVILEGES (optional; requires suitable MySQL account privileges)
-- Create users only on a local/demo database. Use strong passwords and
-- never publish real passwords or credentials in a GitHub repository.

-- CREATE USER 'bookstore_admin'@'localhost' IDENTIFIED BY 'ReplaceWithStrongPassword!';
-- GRANT ALL PRIVILEGES ON Bookstore.* TO 'bookstore_admin'@'localhost';

-- CREATE USER 'bookstore_readonly'@'localhost' IDENTIFIED BY 'ReplaceWithStrongPassword!';
-- GRANT SELECT ON Bookstore.* TO 'bookstore_readonly'@'localhost';

-- REVOKE SELECT ON Bookstore.Customers FROM 'bookstore_readonly'@'localhost';

-- ============================================================
-- END OF PROJECT
-- ============================================================
