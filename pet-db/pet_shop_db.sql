Create Database Shop;
use Shop;

CREATE TABLE users ( 
    user_id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    email_confirmation BOOLEAN DEFAULT FALSE,
    password VARCHAR(255) NOT NULL,
    firstname VARCHAR(50),
    lastname VARCHAR(50)
);

CREATE TABLE specie ( 
    specie_id INT PRIMARY KEY AUTO_INCREMENT,
    specie_name VARCHAR(100) UNIQUE NOT NULL
);

CREATE TABLE CommonName ( 
    id INTEGER PRIMARY KEY AUTO_INCREMENT,
    specie_id INTEGER NOT NULL,
    CommonName VARCHAR(100),
    Constraint fk_specie_id_CommonName FOREIGN KEY (specie_id) REFERENCES specie(specie_id) ON DELETE CASCADE
);


CREATE TABLE LatinName ( 
    id INTEGER PRIMARY KEY AUTO_INCREMENT,
    specie_id INTEGER NOT NULL,
    LatinName VARCHAR(100),
    Constraint fk_specie_id_LatinName FOREIGN KEY (specie_id) REFERENCES specie(specie_id) ON DELETE CASCADE
);

CREATE TABLE pets ( 
    pet_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    specie_id INT NOT NULL,
    birthday DATE,
    pet_given_name VARCHAR(100),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (specie_id) REFERENCES specie(specie_id) ON DELETE CASCADE
);

CREATE TABLE description ( 
    pet_id INT PRIMARY KEY,
    description TEXT,
    alive BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (pet_id) REFERENCES pets(pet_id) ON DELETE CASCADE
);

CREATE TABLE warehouse ( 
    warehouse_id INT PRIMARY KEY AUTO_INCREMENT,
    city VARCHAR(100) NOT NULL
);

CREATE TABLE inventory ( 
    product_id INT NOT NULL,
    warehouse_id INT NOT NULL,
    quantity INT DEFAULT 0 CHECK (quantity >= 0),
    PRIMARY KEY (product_id, warehouse_id),
    FOREIGN KEY (warehouse_id) REFERENCES warehouse(warehouse_id) ON DELETE CASCADE
);

CREATE TABLE manufacturers ( 
    manufacturer_id INT PRIMARY KEY AUTO_INCREMENT,
    manufacturer_name VARCHAR(100) NOT NULL UNIQUE,
    address TEXT,
    contact_person VARCHAR(100),
    manufacturer_email VARCHAR(100),
    manufacturer_mobile VARCHAR(100)
);

CREATE TABLE products ( 
    product_id INT PRIMARY KEY AUTO_INCREMENT,
    SKU VARCHAR(100) UNIQUE NOT NULL,
    product_name VARCHAR(100) NOT NULL,
    manufacturer_id INT NOT NULL,
    buying_price DECIMAL(10,2) NOT NULL CHECK (buying_price >= 0),
    FOREIGN KEY (manufacturer_id) REFERENCES manufacturers(manufacturer_id) ON DELETE CASCADE
);

CREATE TABLE categories ( 
    category_id INT PRIMARY KEY AUTO_INCREMENT,
    category_name VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE product_categories ( 
    product_id INT NOT NULL,
    category_id INT NOT NULL,
    PRIMARY KEY (product_id, category_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES categories(category_id) ON DELETE CASCADE
);

CREATE TABLE product_description ( 
    SKU VARCHAR(50) PRIMARY KEY,
    size VARCHAR(50),
    color VARCHAR(50),
    extra_info TEXT,  -- Tom kolumn, kan fyllas med valfri data
    FOREIGN KEY (SKU) REFERENCES products(SKU) ON DELETE CASCADE
);

CREATE TABLE orders_status ( 
    status_id INT PRIMARY KEY AUTO_INCREMENT,
    status_name VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE orders ( 
    order_id INT PRIMARY KEY AUTO_INCREMENT,
    billing_address TEXT NOT NULL,
    delivery_address TEXT NOT NULL,
    user_id INT NOT NULL,
    status_id INT NOT NULL,
    warehouse_id INT NOT NULL,
    total DECIMAL(10,2) NOT NULL CHECK (total >= 0),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (status_id) REFERENCES orders_status(status_id) ON DELETE RESTRICT,
    FOREIGN KEY (warehouse_id) REFERENCES warehouse(warehouse_id) ON DELETE CASCADE
);

CREATE TABLE orders_items ( 
    order_id INT NOT NULL,
    product_name VARCHAR(100) NOT NULL,
    SKU VARCHAR(100) NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10,2) NOT NULL CHECK (unit_price >= 0),
    PRIMARY KEY (order_id, SKU),
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (SKU) REFERENCES products(SKU) ON DELETE CASCADE
);

CREATE TABLE messages (
    message_id INT PRIMARY KEY AUTO_INCREMENT,
    sender_id INT NOT NULL,
    receiver_id INT NOT NULL,
    parent_message_id INT NULL,  -- Refererar till ett tidigare meddelande om det är ett svar
    content TEXT NOT NULL,
    sent_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (sender_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (receiver_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (parent_message_id) REFERENCES messages(message_id) ON DELETE SET NULL
);

CREATE TABLE audit_log (
    log_id INT PRIMARY KEY AUTO_INCREMENT,
    table_name VARCHAR(100) NOT NULL,
    operation ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
    changed_data JSON NOT NULL,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    changed_by INT,  -- Kan vara NULL om användaren inte är känd
    FOREIGN KEY (changed_by) REFERENCES users(user_id) ON DELETE SET NULL
);
--First
DELIMITER $$

-- Trigger för när en ny order skapas
CREATE TRIGGER orders_after_insert
AFTER INSERT ON orders
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
    VALUES ('orders', 'INSERT', 
            JSON_OBJECT(
                'order_id', NEW.order_id, 
                'billing_address', NEW.billing_address, 
                'delivery_address', NEW.delivery_address, 
                'user_id', NEW.user_id, 
                'status_id', NEW.status_id, 
                'warehouse_id', NEW.warehouse_id, 
                'total', NEW.total), 
            NULL);
END $$

-- Trigger för när en order uppdateras (endast ändrade kolumner loggas)
CREATE TRIGGER orders_after_update
AFTER UPDATE ON orders
FOR EACH ROW
BEGIN
    DECLARE changed_data JSON;
    
    SET changed_data = JSON_OBJECT();

    -- Kolla om 'billing_address' har ändrats
    IF OLD.billing_address != NEW.billing_address THEN
        SET changed_data = JSON_SET(changed_data, '$.billing_address', JSON_OBJECT('old', OLD.billing_address, 'new', NEW.billing_address));
    END IF;

    -- Kolla om 'delivery_address' har ändrats
    IF OLD.delivery_address != NEW.delivery_address THEN
        SET changed_data = JSON_SET(changed_data, '$.delivery_address', JSON_OBJECT('old', OLD.delivery_address, 'new', NEW.delivery_address));
    END IF;

    -- Kolla om 'status_id' har ändrats
    IF OLD.status_id != NEW.status_id THEN
        SET changed_data = JSON_SET(changed_data, '$.status_id', JSON_OBJECT('old', OLD.status_id, 'new', NEW.status_id));
    END IF;

    -- Kolla om 'total' har ändrats
    IF OLD.total != NEW.total THEN
        SET changed_data = JSON_SET(changed_data, '$.total', JSON_OBJECT('old', OLD.total, 'new', NEW.total));
    END IF;

    -- Om det finns ändrade data, logga dem
    IF JSON_LENGTH(changed_data) > 0 THEN
        INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
        VALUES ('orders', 'UPDATE', changed_data, NULL);
    END IF;
END $$

-- Trigger för när en order tas bort
CREATE TRIGGER orders_after_delete
AFTER DELETE ON orders
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
    VALUES ('orders', 'DELETE', 
            JSON_OBJECT(
                'order_id', OLD.order_id, 
                'billing_address', OLD.billing_address, 
                'delivery_address', OLD.delivery_address, 
                'user_id', OLD.user_id, 
                'status_id', OLD.status_id, 
                'warehouse_id', OLD.warehouse_id, 
                'total', OLD.total), 
            NULL);
END $$

-- Trigger för INSERT på orders_status
CREATE TRIGGER orders_status_after_insert
AFTER INSERT ON orders_status
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
    VALUES ('orders_status', 'INSERT', 
            JSON_OBJECT(
                'status_id', NEW.status_id, 
                'status_name', NEW.status_name), 
            NULL);
END $$

-- Trigger för UPDATE på orders_status
CREATE TRIGGER orders_status_after_update
AFTER UPDATE ON orders_status
FOR EACH ROW
BEGIN
    DECLARE changed_data JSON;
    SET changed_data = JSON_OBJECT();

    IF OLD.status_name != NEW.status_name THEN
        SET changed_data = JSON_SET(changed_data, '$.status_name', JSON_OBJECT('old', OLD.status_name, 'new', NEW.status_name));
    END IF;

    IF JSON_LENGTH(changed_data) > 0 THEN
        INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
        VALUES ('orders_status', 'UPDATE', changed_data, NULL);
    END IF;
END $$

-- Trigger för DELETE på orders_status
CREATE TRIGGER orders_status_after_delete
AFTER DELETE ON orders_status
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
    VALUES ('orders_status', 'DELETE', 
            JSON_OBJECT(
                'status_id', OLD.status_id, 
                'status_name', OLD.status_name), 
            NULL);
END $$

-- Trigger för INSERT på orders_items
CREATE TRIGGER orders_items_after_insert
AFTER INSERT ON orders_items
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
    VALUES ('orders_items', 'INSERT', 
            JSON_OBJECT(
                'order_id', NEW.order_id, 
                'product_name', NEW.product_name, 
                'SKU', NEW.SKU, 
                'quantity', NEW.quantity, 
                'unit_price', NEW.unit_price), 
            NULL);
END $$

-- Trigger för UPDATE på orders_items
CREATE TRIGGER orders_items_after_update
AFTER UPDATE ON orders_items
FOR EACH ROW
BEGIN
    DECLARE changed_data JSON;
    SET changed_data = JSON_OBJECT();

    IF OLD.product_name != NEW.product_name THEN
        SET changed_data = JSON_SET(changed_data, '$.product_name', JSON_OBJECT('old', OLD.product_name, 'new', NEW.product_name));
    END IF;

    IF OLD.quantity != NEW.quantity THEN
        SET changed_data = JSON_SET(changed_data, '$.quantity', JSON_OBJECT('old', OLD.quantity, 'new', NEW.quantity));
    END IF;

    IF OLD.unit_price != NEW.unit_price THEN
        SET changed_data = JSON_SET(changed_data, '$.unit_price', JSON_OBJECT('old', OLD.unit_price, 'new', NEW.unit_price));
    END IF;

    IF JSON_LENGTH(changed_data) > 0 THEN
        INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
        VALUES ('orders_items', 'UPDATE', changed_data, NULL);
    END IF;
END $$

-- Trigger för DELETE på orders_items
CREATE TRIGGER orders_items_after_delete
AFTER DELETE ON orders_items
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
    VALUES ('orders_items', 'DELETE', 
            JSON_OBJECT(
                'order_id', OLD.order_id, 
                'product_name', OLD.product_name, 
                'SKU', OLD.SKU, 
                'quantity', OLD.quantity, 
                'unit_price', OLD.unit_price), 
            NULL);
END $$

-- Trigger för när en ny användare skapas
CREATE TRIGGER users_after_insert
AFTER INSERT ON users
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
    VALUES ('users', 'INSERT', 
            JSON_OBJECT(
                'user_id', NEW.user_id, 
                'username', NEW.username, 
                'email', NEW.email, 
                'email_confirmation', NEW.email_confirmation, 
                'firstname', NEW.firstname, 
                'lastname', NEW.lastname), 
            NULL);
END $$

-- Trigger för när en användare uppdateras (loggar endast ändrade kolumner)
CREATE TRIGGER users_after_update
AFTER UPDATE ON users
FOR EACH ROW
BEGIN
    DECLARE changed_data JSON;
    SET changed_data = JSON_OBJECT();

    -- Kolla om 'username' har ändrats
    IF OLD.username != NEW.username THEN
        SET changed_data = JSON_SET(changed_data, '$.username', JSON_OBJECT('old', OLD.username, 'new', NEW.username));
    END IF;

    -- Kolla om 'email' har ändrats
    IF OLD.email != NEW.email THEN
        SET changed_data = JSON_SET(changed_data, '$.email', JSON_OBJECT('old', OLD.email, 'new', NEW.email));
    END IF;

    -- Kolla om 'email_confirmation' har ändrats
    IF OLD.email_confirmation != NEW.email_confirmation THEN
        SET changed_data = JSON_SET(changed_data, '$.email_confirmation', JSON_OBJECT('old', OLD.email_confirmation, 'new', NEW.email_confirmation));
    END IF;

    -- Kolla om 'firstname' har ändrats
    IF OLD.firstname != NEW.firstname THEN
        SET changed_data = JSON_SET(changed_data, '$.firstname', JSON_OBJECT('old', OLD.firstname, 'new', NEW.firstname));
    END IF;

    -- Kolla om 'lastname' har ändrats
    IF OLD.lastname != NEW.lastname THEN
        SET changed_data = JSON_SET(changed_data, '$.lastname', JSON_OBJECT('old', OLD.lastname, 'new', NEW.lastname));
    END IF;

    -- Om det finns ändrade data, logga dem
    IF JSON_LENGTH(changed_data) > 0 THEN
        INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
        VALUES ('users', 'UPDATE', changed_data, NULL);
    END IF;
END $$

-- Trigger för när en användare tas bort
CREATE TRIGGER users_after_delete
AFTER DELETE ON users
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
    VALUES ('users', 'DELETE', 
            JSON_OBJECT(
                'user_id', OLD.user_id, 
                'username', OLD.username, 
                'email', OLD.email, 
                'email_confirmation', OLD.email_confirmation, 
                'firstname', OLD.firstname, 
                'lastname', OLD.lastname), 
            NULL);
END $$

-- Trigger för INSERT på specie
CREATE TRIGGER specie_after_insert
AFTER INSERT ON specie
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
    VALUES ('specie', 'INSERT', 
            JSON_OBJECT(
                'specie_id', NEW.specie_id, 
                'specie_name', NEW.specie_name), 
            NULL);
END $$

-- Trigger för UPDATE på specie
CREATE TRIGGER specie_after_update
AFTER UPDATE ON specie
FOR EACH ROW
BEGIN
    DECLARE changed_data JSON;
    SET changed_data = JSON_OBJECT();

    IF OLD.specie_name != NEW.specie_name THEN
        SET changed_data = JSON_SET(changed_data, '$.specie_name', JSON_OBJECT('old', OLD.specie_name, 'new', NEW.specie_name));
    END IF;

    IF JSON_LENGTH(changed_data) > 0 THEN
        INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
        VALUES ('specie', 'UPDATE', changed_data, NULL);
    END IF;
END $$

-- Trigger för DELETE på specie
CREATE TRIGGER specie_after_delete
AFTER DELETE ON specie
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
    VALUES ('specie', 'DELETE', 
            JSON_OBJECT(
                'specie_id', OLD.specie_id, 
                'specie_name', OLD.specie_name), 
            NULL);
END $$

-- Trigger för INSERT på CommonName
CREATE TRIGGER CommonName_after_insert
AFTER INSERT ON CommonName
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
    VALUES ('CommonName', 'INSERT', 
            JSON_OBJECT(
                'specie_id', NEW.specie_id, 
                'CommonName', NEW.CommonName), 
            NULL);
END $$

-- Trigger för DELETE på CommonName
CREATE TRIGGER CommonName_after_delete
AFTER DELETE ON CommonName
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
    VALUES ('CommonName', 'DELETE', 
            JSON_OBJECT(
                'specie_id', OLD.specie_id, 
                'CommonName', OLD.CommonName), 
            NULL);
END $$

-- Trigger för INSERT på LatinName
CREATE TRIGGER LatinName_after_insert
AFTER INSERT ON LatinName
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
    VALUES ('LatinName', 'INSERT', 
            JSON_OBJECT(
                'specie_id', NEW.specie_id, 
                'LatinName', NEW.LatinName), 
            NULL);
END $$

-- Trigger för DELETE på LatinName
CREATE TRIGGER LatinName_after_delete
AFTER DELETE ON LatinName
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
    VALUES ('LatinName', 'DELETE', 
            JSON_OBJECT(
                'specie_id', OLD.specie_id, 
                'LatinName', OLD.LatinName), 
            NULL);
END $$

-- Trigger för INSERT på pets
CREATE TRIGGER pets_after_insert
AFTER INSERT ON pets
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
    VALUES ('pets', 'INSERT', 
            JSON_OBJECT(
                'pet_id', NEW.pet_id, 
                'user_id', NEW.user_id, 
                'specie_id', NEW.specie_id, 
                'birthday', NEW.birthday, 
                'pet_given_name', NEW.pet_given_name), 
            NULL);
END $$

-- Trigger för UPDATE på pets
CREATE TRIGGER pets_after_update
AFTER UPDATE ON pets
FOR EACH ROW
BEGIN
    DECLARE changed_data JSON;
    SET changed_data = JSON_OBJECT();

    IF OLD.user_id != NEW.user_id THEN
        SET changed_data = JSON_SET(changed_data, '$.user_id', JSON_OBJECT('old', OLD.user_id, 'new', NEW.user_id));
    END IF;

    IF OLD.specie_id != NEW.specie_id THEN
        SET changed_data = JSON_SET(changed_data, '$.specie_id', JSON_OBJECT('old', OLD.specie_id, 'new', NEW.specie_id));
    END IF;

    IF OLD.birthday != NEW.birthday THEN
        SET changed_data = JSON_SET(changed_data, '$.birthday', JSON_OBJECT('old', OLD.birthday, 'new', NEW.birthday));
    END IF;

    IF OLD.pet_given_name != NEW.pet_given_name THEN
        SET changed_data = JSON_SET(changed_data, '$.pet_given_name', JSON_OBJECT('old', OLD.pet_given_name, 'new', NEW.pet_given_name));
    END IF;

    IF JSON_LENGTH(changed_data) > 0 THEN
        INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
        VALUES ('pets', 'UPDATE', changed_data, NULL);
    END IF;
END $$

-- Trigger för DELETE på pets
CREATE TRIGGER pets_after_delete
AFTER DELETE ON pets
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
    VALUES ('pets', 'DELETE', 
            JSON_OBJECT(
                'pet_id', OLD.pet_id, 
                'user_id', OLD.user_id, 
                'specie_id', OLD.specie_id, 
                'birthday', OLD.birthday, 
                'pet_given_name', OLD.pet_given_name), 
            NULL);
END $$

-- Trigger för INSERT på description
CREATE TRIGGER description_after_insert
AFTER INSERT ON description
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
    VALUES ('description', 'INSERT', 
            JSON_OBJECT(
                'pet_id', NEW.pet_id, 
                'description', NEW.description, 
                'alive', NEW.alive), 
            NULL);
END $$

-- Trigger för UPDATE på description
CREATE TRIGGER description_after_update
AFTER UPDATE ON description
FOR EACH ROW
BEGIN
    DECLARE changed_data JSON;
    SET changed_data = JSON_OBJECT();

    IF OLD.description != NEW.description THEN
        SET changed_data = JSON_SET(changed_data, '$.description', JSON_OBJECT('old', OLD.description, 'new', NEW.description));
    END IF;

    IF OLD.alive != NEW.alive THEN
        SET changed_data = JSON_SET(changed_data, '$.alive', JSON_OBJECT('old', OLD.alive, 'new', NEW.alive));
    END IF;

    IF JSON_LENGTH(changed_data) > 0 THEN
        INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
        VALUES ('description', 'UPDATE', changed_data, NULL);
    END IF;
END $$

-- Trigger för DELETE på description
CREATE TRIGGER description_after_delete
AFTER DELETE ON description
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
    VALUES ('description', 'DELETE', 
            JSON_OBJECT(
                'pet_id', OLD.pet_id, 
                'description', OLD.description, 
                'alive', OLD.alive), 
            NULL);
END $$

-- Trigger för INSERT på warehouse
CREATE TRIGGER warehouse_after_insert
AFTER INSERT ON warehouse
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
    VALUES ('warehouse', 'INSERT', 
            JSON_OBJECT(
                'warehouse_id', NEW.warehouse_id, 
                'city', NEW.city), 
            NULL);
END $$

-- Trigger för UPDATE på warehouse
CREATE TRIGGER warehouse_after_update
AFTER UPDATE ON warehouse
FOR EACH ROW
BEGIN
    DECLARE changed_data JSON;
    SET changed_data = JSON_OBJECT();

    IF OLD.city != NEW.city THEN
        SET changed_data = JSON_SET(changed_data, '$.city', JSON_OBJECT('old', OLD.city, 'new', NEW.city));
    END IF;

    IF JSON_LENGTH(changed_data) > 0 THEN
        INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
        VALUES ('warehouse', 'UPDATE', changed_data, NULL);
    END IF;
END $$

-- Trigger för DELETE på warehouse
CREATE TRIGGER warehouse_after_delete
AFTER DELETE ON warehouse
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
    VALUES ('warehouse', 'DELETE', 
            JSON_OBJECT(
                'warehouse_id', OLD.warehouse_id, 
                'city', OLD.city), 
            NULL);
END $$

-- Trigger för INSERT på inventory
CREATE TRIGGER inventory_after_insert
AFTER INSERT ON inventory
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
    VALUES ('inventory', 'INSERT', 
            JSON_OBJECT(
                'product_id', NEW.product_id, 
                'warehouse_id', NEW.warehouse_id, 
                'quantity', NEW.quantity), 
            NULL);
END $$

-- Trigger för UPDATE på inventory
CREATE TRIGGER inventory_after_update
AFTER UPDATE ON inventory
FOR EACH ROW
BEGIN
    DECLARE changed_data JSON;
    SET changed_data = JSON_OBJECT();

    IF OLD.quantity != NEW.quantity THEN
        SET changed_data = JSON_SET(changed_data, '$.quantity', JSON_OBJECT('old', OLD.quantity, 'new', NEW.quantity));
    END IF;

    IF JSON_LENGTH(changed_data) > 0 THEN
        INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
        VALUES ('inventory', 'UPDATE', changed_data, NULL);
    END IF;
END $$

-- Trigger för DELETE på inventory
CREATE TRIGGER inventory_after_delete
AFTER DELETE ON inventory
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
    VALUES ('inventory', 'DELETE', 
            JSON_OBJECT(
                'product_id', OLD.product_id, 
                'warehouse_id', OLD.warehouse_id, 
                'quantity', OLD.quantity), 
            NULL);
END $$

-- Trigger för INSERT på manufacturers
CREATE TRIGGER manufacturers_after_insert
AFTER INSERT ON manufacturers
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
    VALUES ('manufacturers', 'INSERT', 
            JSON_OBJECT(
                'manufacturer_id', NEW.manufacturer_id, 
                'manufacturer_name', NEW.manufacturer_name, 
                'contact_person', NEW.contact_person, 
                'address', NEW.address), 
            NULL);
END $$

-- Trigger för UPDATE på manufacturers
CREATE TRIGGER manufacturers_after_update
AFTER UPDATE ON manufacturers
FOR EACH ROW
BEGIN
    DECLARE changed_data JSON;
    SET changed_data = JSON_OBJECT();

    IF OLD.manufacturer_name != NEW.manufacturer_name THEN
        SET changed_data = JSON_SET(changed_data, '$.manufacturer_name', JSON_OBJECT('old', OLD.manufacturer_name, 'new', NEW.manufacturer_name));
    END IF;

    IF OLD.contact_person != NEW.contact_person THEN
        SET changed_data = JSON_SET(changed_data, '$.contact_person', JSON_OBJECT('old', OLD.contact_person, 'new', NEW.contact_person));
    END IF;

    IF OLD.address != NEW.address THEN
        SET changed_data = JSON_SET(changed_data, '$.address', JSON_OBJECT('old', OLD.address, 'new', NEW.address));
    END IF;

    IF JSON_LENGTH(changed_data) > 0 THEN
        INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
        VALUES ('manufacturers', 'UPDATE', changed_data, NULL);
    END IF;
END $$

-- Trigger för DELETE på manufacturers
CREATE TRIGGER manufacturers_after_delete
AFTER DELETE ON manufacturers
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
    VALUES ('manufacturers', 'DELETE', 
            JSON_OBJECT(
                'manufacturer_id', OLD.manufacturer_id, 
                'manufacturer_name', OLD.manufacturer_name, 
                'contact_person', OLD.contact_person, 
                'address', OLD.address), 
            NULL);
END $$

-- Trigger för INSERT på products
CREATE TRIGGER products_after_insert
AFTER INSERT ON products
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
    VALUES ('products', 'INSERT', 
            JSON_OBJECT(
                'product_id', NEW.product_id, 
                'SKU', NEW.SKU, 
                'product_name', NEW.product_name, 
                'manufacturer_id', NEW.manufacturer_id, 
                'buying_price', NEW.buying_price), 
            NULL);
END $$

-- Trigger för UPDATE på products
CREATE TRIGGER products_after_update
AFTER UPDATE ON products
FOR EACH ROW
BEGIN
    DECLARE changed_data JSON;
    SET changed_data = JSON_OBJECT();

    IF OLD.product_name != NEW.product_name THEN
        SET changed_data = JSON_SET(changed_data, '$.product_name', JSON_OBJECT('old', OLD.product_name, 'new', NEW.product_name));
    END IF;

    IF OLD.manufacturer_id != NEW.manufacturer_id THEN
        SET changed_data = JSON_SET(changed_data, '$.manufacturer_id', JSON_OBJECT('old', OLD.manufacturer_id, 'new', NEW.manufacturer_id));
    END IF;

    IF OLD.buying_price != NEW.buying_price THEN
        SET changed_data = JSON_SET(changed_data, '$.buying_price', JSON_OBJECT('old', OLD.buying_price, 'new', NEW.buying_price));
    END IF;

    IF JSON_LENGTH(changed_data) > 0 THEN
        INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
        VALUES ('products', 'UPDATE', changed_data, NULL);
    END IF;
END $$

-- Trigger för DELETE på products
CREATE TRIGGER products_after_delete
AFTER DELETE ON products
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
    VALUES ('products', 'DELETE', 
            JSON_OBJECT(
                'product_id', OLD.product_id, 
                'SKU', OLD.SKU, 
                'product_name', OLD.product_name, 
                'manufacturer_id', OLD.manufacturer_id, 
                'buying_price', OLD.buying_price), 
            NULL);
END $$

-- Trigger för INSERT på categories
CREATE TRIGGER categories_after_insert
AFTER INSERT ON categories
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
    VALUES ('categories', 'INSERT', 
            JSON_OBJECT(
                'category_id', NEW.category_id, 
                'category_name', NEW.category_name), 
            NULL);
END $$

-- Trigger för DELETE på categories
CREATE TRIGGER categories_after_delete
AFTER DELETE ON categories
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
    VALUES ('categories', 'DELETE', 
            JSON_OBJECT(
                'category_id', OLD.category_id, 
                'category_name', OLD.category_name), 
            NULL);
END $$

-- Trigger för INSERT på product_categories
CREATE TRIGGER product_categories_after_insert
AFTER INSERT ON product_categories
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
    VALUES ('product_categories', 'INSERT', 
            JSON_OBJECT(
                'product_id', NEW.product_id, 
                'category_id', NEW.category_id), 
            NULL);
END $$

-- Trigger för DELETE på product_categories
CREATE TRIGGER product_categories_after_delete
AFTER DELETE ON product_categories
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
    VALUES ('product_categories', 'DELETE', 
            JSON_OBJECT(
                'product_id', OLD.product_id, 
                'category_id', OLD.category_id), 
            NULL);
END $$

-- Trigger för INSERT på product_description
CREATE TRIGGER product_description_after_insert
AFTER INSERT ON product_description
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
    VALUES ('product_description', 'INSERT', 
            JSON_OBJECT(
                'SKU', NEW.SKU, 
                'size', NEW.size, 
                'color', NEW.color, 
                'extra_info', NEW.extra_info), 
            NULL);
END $$

-- Trigger för UPDATE på product_description
CREATE TRIGGER product_description_after_update
AFTER UPDATE ON product_description
FOR EACH ROW
BEGIN
    DECLARE changed_data JSON;
    SET changed_data = JSON_OBJECT();

    IF OLD.size != NEW.size THEN
        SET changed_data = JSON_SET(changed_data, '$.size', JSON_OBJECT('old', OLD.size, 'new', NEW.size));
    END IF;

    IF OLD.color != NEW.color THEN
        SET changed_data = JSON_SET(changed_data, '$.color', JSON_OBJECT('old', OLD.color, 'new', NEW.color));
    END IF;

    IF OLD.extra_info != NEW.extra_info THEN
        SET changed_data = JSON_SET(changed_data, '$.extra_info', JSON_OBJECT('old', OLD.extra_info, 'new', NEW.extra_info));
    END IF;

    IF JSON_LENGTH(changed_data) > 0 THEN
        INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
        VALUES ('product_description', 'UPDATE', changed_data, NULL);
    END IF;
END $$

-- Trigger för DELETE på product_description
CREATE TRIGGER product_description_after_delete
AFTER DELETE ON product_description
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, changed_data, changed_by)
    VALUES ('product_description', 'DELETE', 
            JSON_OBJECT(
                'SKU', OLD.SKU, 
                'size', OLD.size, 
                'color', OLD.color, 
                'extra_info', OLD.extra_info), 
            NULL);
END $$

--Last
DELIMITER ;

CREATE VIEW view_messages AS
SELECT 
    m.message_id, 
    u1.username AS sender, 
    u2.username AS receiver, 
    m.content, 
    m.sent_at, 
    m.parent_message_id
FROM messages m
JOIN users u1 ON m.sender_id = u1.user_id
JOIN users u2 ON m.receiver_id = u2.user_id;

CREATE VIEW view_products_categories AS
SELECT 
    p.product_id, 
    p.product_name, 
    c.category_name
FROM products p
JOIN product_categories pc ON p.product_id = pc.product_id
JOIN categories c ON pc.category_id = c.category_id;


CREATE VIEW view_orders AS
SELECT 
    o.order_id, 
    u.username, 
    o.billing_address, 
    o.delivery_address, 
    s.status_name, 
    o.total
FROM orders o
JOIN users u ON o.user_id = u.user_id
JOIN orders_status s ON o.status_id = s.status_id;

CREATE VIEW view_inventory AS
SELECT 
    i.product_id, 
    p.product_name, 
    w.city AS warehouse_location, 
    i.quantity
FROM inventory i
JOIN products p ON i.product_id = p.product_id
JOIN warehouse w ON i.warehouse_id = w.warehouse_id;

CREATE VIEW view_pets AS
SELECT 
    p.pet_id, 
    u.username AS owner, 
    s.specie_name, 
    p.pet_given_name, 
    p.birthday, 
    d.description, 
    d.alive
FROM pets p
JOIN users u ON p.user_id = u.user_id
JOIN specie s ON p.specie_id = s.specie_id
LEFT JOIN description d ON p.pet_id = d.pet_id;


--Population
INSERT INTO users (firstname, lastname, username, email, email_confirmation, password) VALUES
('Alice', 'Johnson', 'alice.johnson', 'alice.johnson@example.com', TRUE, SHA2('securepass1', 256)),
('Bob', 'Smith', 'bob.smith', 'bob.smith@example.com', FALSE, SHA2('securepass2', 256)),
('Carla', 'Martinez', 'carla.martinez', 'carla.martinez@example.com', TRUE, SHA2('securepass3', 256)),
('David', 'Lee', 'david.lee', 'david.lee@example.com', FALSE, SHA2('securepass4', 256)),
('Emma', 'Wilson', 'emma.wilson', 'emma.wilson@example.com', TRUE, SHA2('securepass5', 256)),
('Frank', 'Harris', 'frank.harris', 'frank.harris@example.com', FALSE, SHA2('securepass6', 256)),
('Grace', 'Clark', 'grace.clark', 'grace.clark@example.com', TRUE, SHA2('securepass7', 256)),
('Henry', 'Evans', 'henry.evans', 'henry.evans@example.com', FALSE, SHA2('securepass8', 256)),
('Isabella', 'Moore', 'isabella.moore', 'isabella.moore@example.com', TRUE, SHA2('securepass9', 256)),
('Jackson', 'White', 'jackson.white', 'jackson.white@example.com', FALSE, SHA2('securepass10', 256)),
('Karen', 'Davis', 'karen.davis', 'karen.davis@example.com', TRUE, SHA2('securepass11', 256)),
('Leo', 'Miller', 'leo.miller', 'leo.miller@example.com', FALSE, SHA2('securepass12', 256)),
('Mia', 'Anderson', 'mia.anderson', 'mia.anderson@example.com', TRUE, SHA2('securepass13', 256)),
('Noah', 'Thomas', 'noah.thomas', 'noah.thomas@example.com', FALSE, SHA2('securepass14', 256)),
('Olivia', 'Taylor', 'olivia.taylor', 'olivia.taylor@example.com', TRUE, SHA2('securepass15', 256)),
('Peter', 'Hall', 'peter.hall', 'peter.hall@example.com', FALSE, SHA2('securepass16', 256)),
('Quinn', 'Adams', 'quinn.adams', 'quinn.adams@example.com', TRUE, SHA2('securepass17', 256)),
('Ryan', 'Scott', 'ryan.scott', 'ryan.scott@example.com', FALSE, SHA2('securepass18', 256)),
('Sophia', 'Baker', 'sophia.baker', 'sophia.baker@example.com', TRUE, SHA2('securepass19', 256)),
('Tyler', 'Wright', 'tyler.wright', 'tyler.wright@example.com', FALSE, SHA2('securepass20', 256));

INSERT INTO specie (specie_name) VALUES
('Lion'),
('Tiger'),
('Elephant'),
('Giraffe'),
('Zebra'),
('Kangaroo'),
('Panda'),
('Koala'),
('Cheetah'),
('Penguin'),
('Dolphin'),
('Shark'),
('Eagle'),
('Owl'),
('Wolf'),
('Bear'),
('Crocodile'),
('Chimpanzee'),
('Hippopotamus'),
('Rhinoceros');

INSERT INTO CommonName (specie_id, CommonName) VALUES
(1, 'Lion'),
(1, 'Simba'),
(2, 'Tiger'),
(3, 'Elephant'),
(4, 'Giraffe'),
(5, 'Zebra'),
(6, 'Kangaroo'),
(7, 'Panda'),
(8, 'Koala'),
(9, 'Cheetah'),
(10, 'Penguin'),
(11, 'Dolphin'),
(12, 'Shark'),
(13, 'Eagle'),
(14, 'Owl'),
(15, 'Wolf'),
(16, 'Bear'),
(17, 'Crocodile'),
(18, 'Chimpanzee'),
(19, 'Hippopotamus'),
(20, 'Rhinoceros');

INSERT INTO LatinName (specie_id, LatinName) VALUES
(1, 'Panthera leo'),
(2, 'Panthera tigris'),
(3, 'Loxodonta africana'),
(4, 'Giraffa camelopardalis'),
(5, 'Equus quagga'),
(6, 'Macropus giganteus'),
(7, 'Ailuropoda melanoleuca'),
(8, 'Phascolarctos cinereus'),
(9, 'Acinonyx jubatus'),
(10, 'Aptenodytes forsteri'),
(11, 'Delphinus delphis'),
(12, 'Carcharodon carcharias'),
(13, 'Haliaeetus leucocephalus'),
(14, 'Bubo bubo'),
(15, 'Canis lupus'),
(16, 'Ursus arctos'),
(17, 'Crocodylus niloticus'),
(18, 'Pan troglodytes'),
(19, 'Hippopotamus amphibius'),
(20, 'Rhinoceros unicornis');

-- Populera pets-tabellen
INSERT INTO pets (user_id, specie_id, birthday, pet_given_name) VALUES
(1, 3, '2018-06-15', 'Dumbo'),       -- Elephant
(2, 7, '2020-03-22', 'Bamboo'),      -- Panda
(3, 15, '2019-08-10', 'Ghost'),      -- Wolf
(4, 5, '2021-05-30', 'Stripe'),      -- Zebra
(5, 10, '2017-11-12', 'Flippers'),   -- Penguin
(6, 12, '2016-09-05', 'Jaws'),       -- Shark
(7, 1, '2019-04-25', 'Simba'),       -- Lion
(8, 2, '2022-02-18', 'Rajah'),       -- Tiger
(9, 6, '2020-07-07', 'Hoppy'),       -- Kangaroo
(10, 4, '2015-12-01', 'Stretch'),    -- Giraffe
(11, 9, '2018-10-20', 'Spot'),       -- Cheetah
(12, 8, '2021-01-15', 'Sleepy'),     -- Koala
(13, 11, '2014-05-23', 'Echo'),      -- Dolphin
(14, 13, '2017-06-30', 'Sky'),       -- Eagle
(15, 14, '2019-09-12', 'Hoot'),      -- Owl
(16, 16, '2013-08-17', 'Bruno'),     -- Bear
(17, 17, '2012-07-27', 'Snap'),      -- Crocodile
(18, 18, '2020-10-10', 'Charlie'),   -- Chimpanzee
(19, 19, '2015-02-14', 'Hippo'),     -- Hippopotamus
(20, 20, '2018-11-03', 'Rhino');     -- Rhinoceros

-- Populera description-tabellen
INSERT INTO description (pet_id, description, alive) VALUES
(1, 'A friendly elephant who loves peanuts.', TRUE),
(2, 'Loves to munch on bamboo all day.', TRUE),
(3, 'A majestic wolf with a silver coat.', TRUE),
(4, 'A playful zebra who enjoys running.', TRUE),
(5, 'A penguin who loves to slide on ice.', TRUE),
(6, 'A great white shark, fearsome yet graceful.', TRUE),
(7, 'A young lion with a mighty roar.', TRUE),
(8, 'A strong and stealthy tiger.', TRUE),
(9, 'A kangaroo that jumps incredibly high.', TRUE),
(10, 'A tall giraffe with a gentle nature.', TRUE),
(11, 'A lightning-fast cheetah.', TRUE),
(12, 'A sleepy koala who naps all day.', TRUE),
(13, 'A highly intelligent dolphin.', TRUE),
(14, 'An eagle soaring high in the sky.', TRUE),
(15, 'A wise old owl.', TRUE),
(16, 'A big brown bear who loves honey.', TRUE),
(17, 'A powerful crocodile with sharp teeth.', TRUE),
(18, 'A curious chimpanzee.', TRUE),
(19, 'A huge hippopotamus who loves water.', TRUE),
(20, 'A strong rhinoceros with a mighty horn.', TRUE);

INSERT INTO warehouse (city) VALUES
('Stockholm'),
('Gothenburg'),
('Malmo'),
('Uppsala'),
('Vasteras'),
('Orebro'),
('Linkoping'),
('Helsingborg'),
('Jonkoping'),
('Norrkoping'),
('Lund'),
('Umea'),
('Gavle'),
('Boras'),
('Sodertalje'),
('Karlstad'),
('Eskilstuna'),
('Halmstad'),
('Vaxjo'),
('Ostersund');

--inventory
INSERT INTO inventory (product_id, warehouse_id, quantity) VALUES
(1, 1, 150),   -- Premium Dog Food, Stockholm
(1, 5, 150),   -- Premium Dog Food, Stockholm
(2, 2, 200),   -- Cat Scratching Post, Gothenburg
(3, 3, 180),   -- Bird Cage, Malmo
(4, 4, 220),   -- Fish Tank 50L, Uppsala
(5, 5, 100),   -- Rabbit Hutch, Vasteras
(6, 6, 120),   -- Reptile Heating Lamp, Orebro
(7, 7, 300),   -- Automatic Pet Feeder, Linkoping
(8, 8, 250),   -- Dog Leash (Adjustable), Helsingborg
(9, 9, 130),   -- Cat Litter Box, Jonkoping
(10, 10, 200),  -- Hamster Wheel, Norrkoping
(11, 11, 180),  -- Pet Shampoo (Aloe Vera), Lund
(12, 12, 220),  -- Dog Chew Toys (Pack of 3), Umea
(13, 13, 150),  -- Parrot Perch, Gavle
(14, 14, 200),  -- Pet Carrier (Small), Boras
(15, 15, 170),  -- Aquarium Filter, Sodertalje
(16, 16, 190),  -- Guinea Pig Hay Feeder, Karlstad
(17, 17, 220),  -- Cat Tree Tower, Eskilstuna
(18, 18, 250),  -- Dog Training Clicker, Halmstad
(19, 19, 180),  -- Pet Cooling Mat, Vaxjo
(20, 20, 160);  -- Turtle Dock, Ostersund

INSERT INTO manufacturers (manufacturer_name, contact_person, address, manufacturer_email, manufacturer_mobile) VALUES
('Paws & Whiskers', 'Anna Johansson', 'Sveavägen 12, Stockholm, Sweden', 'anna@pawswhiskers.com', '+46 70 123 45 67'),
('PetCare Solutions', 'John Smith', 'Olofsgatan 4, Gothenburg, Sweden', 'john@petcaresolutions.com', '+46 70 234 56 78'),
('Furry Friends Inc.', 'Emma Andersson', 'Centralgatan 21, Malmo, Sweden', 'emma@furryfriends.com', '+46 70 345 67 89'),
('Happy Pets Ltd.', 'Lars Svensson', 'Parkvägen 15, Uppsala, Sweden', 'lars@happypets.com', '+46 70 456 78 90'),
('Woof & Meow Ltd.', 'Maria Lindgren', 'Torggatan 7, Vasteras, Sweden', 'maria@woofmeow.com', '+46 70 567 89 01'),
('Animal Kingdom', 'Peter Eriksson', 'Långgatan 3, Orebro, Sweden', 'peter@animalkingdom.com', '+46 70 678 90 12'),
('PetCo', 'Linda Nilsson', 'Kyrkogatan 5, Linkoping, Sweden', 'linda@petco.com', '+46 70 789 01 23'),
('The Pet Shop', 'Anders Holm', 'Lilla Torget 10, Helsingborg, Sweden', 'anders@thepetshop.com', '+46 70 890 12 34'),
('Purrfect Pet Supplies', 'Sara Karlsson', 'Kungsgatan 2, Jonkoping, Sweden', 'sara@purrfectpets.com', '+46 70 901 23 45'),
('Barking Good Ltd.', 'Oskar Larsson', 'Storgatan 8, Norrkoping, Sweden', 'oskar@barkinggood.com', '+46 70 012 34 56'),
('Pet World', 'Elin Olsson', 'Norra Gatan 9, Lund, Sweden', 'elin@petworld.com', '+46 70 123 45 67'),
('Tail Waggers', 'Fredrik Månsson', 'Helsingegatan 6, Umea, Sweden', 'fredrik@tailwaggers.com', '+46 70 234 56 78'),
('The Paws Place', 'Karin Svensson', 'Tomasgatan 14, Gavle, Sweden', 'karin@thepawsplace.com', '+46 70 345 67 89'),
('Fluffy Friends', 'Johan Karlsson', 'Fiskargatan 16, Boras, Sweden', 'johan@fluffyfriends.com', '+46 70 456 78 90'),
('Pet Palace', 'Hanna Jonsson', 'Sodra Gatan 11, Sodertalje, Sweden', 'hanna@petpalace.com', '+46 70 567 89 01'),
('Pets R Us', 'Viktor Nyström', 'Skolgatan 23, Karlstad, Sweden', 'viktor@petsrus.com', '+46 70 678 90 12'),
('PetLove', 'Tove Persson', 'Kungsgatan 5, Eskilstuna, Sweden', 'tove@petlove.com', '+46 70 789 01 23'),
('Best Friends Pet Supplies', 'Olof Berg', 'Fyrgatan 13, Halmstad, Sweden', 'olof@bestfriendspet.com', '+46 70 890 12 34'),
('The Pet Factory', 'Birgitta Nyberg', 'Stadsgatan 2, Vaxjo, Sweden', 'birgitta@petfactory.com', '+46 70 901 23 45'),
('Happy Tails', 'Gustav Larsson', 'Södra Gatan 8, Ostersund, Sweden', 'gustav@happytails.com', '+46 70 012 34 56');


--products
INSERT INTO products (SKU, product_name, manufacturer_id, buying_price) VALUES
('PET-1001', 'Premium Dog Food', 1, 299.99),
('PET-1002', 'Cat Scratching Post', 2, 499.00),
('PET-1003', 'Bird Cage', 3, 899.00),
('PET-1004', 'Fish Tank 50L', 4, 1299.00),
('PET-1005', 'Rabbit Hutch', 5, 799.00),
('PET-1006', 'Reptile Heating Lamp', 6, 349.00),
('PET-1007', 'Automatic Pet Feeder', 7, 599.00),
('PET-1008', 'Dog Leash (Adjustable)', 8, 199.00),
('PET-1009', 'Cat Litter Box', 9, 299.00),
('PET-1010', 'Hamster Wheel', 10, 149.00),
('PET-1011', 'Pet Shampoo (Aloe Vera)', 11, 99.00),
('PET-1012', 'Dog Chew Toys (Pack of 3)', 12, 249.00),
('PET-1013', 'Parrot Perch', 13, 179.00),
('PET-1014', 'Pet Carrier (Small)', 14, 699.00),
('PET-1015', 'Aquarium Filter', 15, 499.00),
('PET-1016', 'Guinea Pig Hay Feeder', 16, 199.00),
('PET-1017', 'Cat Tree Tower', 17, 1299.00),
('PET-1018', 'Dog Training Clicker', 18, 79.00),
('PET-1019', 'Pet Cooling Mat', 19, 399.00),
('PET-1020', 'Turtle Dock', 20, 259.00);

-- Lägg till kategorier
INSERT INTO categories (category_name) VALUES
('Food'),
('Toys'),
('Grooming'),
('Furniture'),
('Accessories'),
('Health');

-- Koppla produkter till kategorier
INSERT INTO product_categories (product_id, category_id) VALUES
(1, 1),   -- Premium Dog Food -> Food
(2, 4),   -- Cat Scratching Post -> Furniture
(3, 4),   -- Bird Cage -> Furniture
(4, 4),   -- Fish Tank 50L -> Furniture
(5, 4),   -- Rabbit Hutch -> Furniture
(6, 5),   -- Reptile Heating Lamp -> Accessories
(7, 1),   -- Automatic Pet Feeder -> Food
(8, 5),   -- Dog Leash (Adjustable) -> Accessories
(9, 4),   -- Cat Litter Box -> Furniture
(10, 2),  -- Hamster Wheel -> Toys
(11, 3),  -- Pet Shampoo (Aloe Vera) -> Grooming
(12, 2),  -- Dog Chew Toys (Pack of 3) -> Toys
(13, 4),  -- Parrot Perch -> Furniture
(14, 5),  -- Pet Carrier (Small) -> Accessories
(15, 3),  -- Aquarium Filter -> Grooming
(16, 1),  -- Guinea Pig Hay Feeder -> Food
(17, 4),  -- Cat Tree Tower -> Furniture
(18, 2),  -- Dog Training Clicker -> Toys
(19, 3),  -- Pet Cooling Mat -> Grooming
(20, 4);  -- Turtle Dock -> Furniture

--product_description
INSERT INTO product_description (SKU, size, color, extra_info) VALUES
('PET-1001', 'Large', 'Brown', 'High-quality ingredients for dogs of all breeds.'),
('PET-1002', 'Medium', 'Gray', 'Durable and perfect for scratching. Ideal for indoor cats.'),
('PET-1003', 'Small', 'White', 'Spacious design with secure locking mechanism.'),
('PET-1004', 'Large', 'Black', 'Includes water filter and LED lighting for optimal fish care.'),
('PET-1005', 'Medium', 'Natural Wood', 'Spacious hutch with multiple levels and safe doors.'),
('PET-1006', 'Medium', 'Black', 'Helps maintain a stable temperature for reptiles.'),
('PET-1007', 'Medium', 'Silver', 'Automatically dispenses food for your pet at scheduled times.'),
('PET-1008', 'Large', 'Red', 'Adjustable to fit dogs of all sizes. Comfortable grip.'),
('PET-1009', 'Large', 'White', 'Easy to clean, ideal for cats of all sizes.'),
('PET-1010', 'Small', 'Transparent', 'Exercise wheel for small pets like hamsters and gerbils.'),
('PET-1011', '500ml', 'Clear', 'Gentle on pets’ skin, made with aloe vera for a soothing effect.'),
('PET-1012', 'Small', 'Blue', 'Includes a variety of flavors for your dog to enjoy.'),
('PET-1013', 'Small', 'Green', 'Perch designed for small to medium-sized birds.'),
('PET-1014', 'Small', 'Black', 'Portable carrier, perfect for small pets or trips.'),
('PET-1015', 'Medium', 'Gray', 'High-performance filter designed for both fresh and saltwater tanks.'),
('PET-1016', 'Small', 'Green', 'Perfect hay feeder for guinea pigs and rabbits.'),
('PET-1017', 'Large', 'Beige', 'Multiple levels for climbing and resting.'),
('PET-1018', 'Small', 'Pink', 'Clicker for dog training and behavior reinforcement.'),
('PET-1019', 'Medium', 'Blue', 'Cooling mat for pets during hot weather.'),
('PET-1020', 'Small', 'Gray', 'Floating dock ideal for turtles and amphibians.');

--Status
INSERT INTO orders_status (status_name) VALUES 
('awaiting'), 
('fulfilled'), 
('cancelled');

INSERT INTO orders (billing_address, delivery_address, user_id, status_id, warehouse_id, total) VALUES
('Kungsgatan 10, Stockholm', 'Sveavägen 15, Stockholm', 1, 1, 1, 1500.00),
('Storgatan 22, Gothenburg', 'Haga 5, Gothenburg', 2, 2, 2, 2000.00),
('Lilla Torg 7, Malmo', 'Ostra Hamngatan 18, Malmo', 3, 3, 3, 1800.00),
('Västerlånggatan 12, Uppsala', 'Stora Torget 5, Uppsala', 4, 1, 4, 2200.00),
('Torggatan 6, Vasteras', 'Malmgatan 9, Vasteras', 5, 2, 5, 1600.00),
('Kyrkogatan 3, Orebro', 'Bergsgatan 8, Orebro', 6, 3, 6, 1750.00),
('Lilla Torget 4, Linkoping', 'Gamla Vägen 11, Linkoping', 7, 1, 7, 2100.00),
('Norra Gatan 9, Helsingborg', 'Södra Strandgatan 4, Helsingborg', 8, 2, 8, 1950.00),
('Parkvägen 14, Jonkoping', 'Vägen till Solsidan 7, Jonkoping', 9, 3, 9, 1850.00),
('Kungsgatan 5, Norrkoping', 'Hantverksgatan 13, Norrkoping', 10, 1, 10, 1700.00),
('Helsingegatan 2, Lund', 'Norra Stationsgatan 1, Lund', 11, 2, 11, 2000.00),
('Fiskargatan 3, Umea', 'Folkets Gata 6, Umea', 12, 3, 12, 2200.00),
('Tomasgatan 8, Gavle', 'Södra Kyrkogatan 10, Gavle', 13, 1, 13, 1800.00),
('Fiskargatan 7, Boras', 'Kyrkogatan 15, Boras', 14, 2, 14, 1750.00),
('Sodra Gatan 5, Sodertalje', 'Västra Gatan 2, Sodertalje', 15, 3, 15, 1950.00),
('Stadsgatan 9, Karlstad', 'Sundsvallsgatan 13, Karlstad', 16, 1, 16, 2000.00),
('Fyrgatan 6, Eskilstuna', 'Västerlånggatan 3, Eskilstuna', 17, 2, 17, 1850.00),
('Stadshusgatan 8, Halmstad', 'Högskolevägen 4, Halmstad', 18, 3, 18, 2100.00),
('Södra Gatan 11, Vaxjo', 'Tärnvägen 9, Vaxjo', 19, 1, 19, 2300.00),
('Hantverkargatan 15, Ostersund', 'Västerdalsgatan 2, Ostersund', 20, 2, 20, 1950.00);

INSERT INTO orders_items (order_id, product_name, SKU, quantity, unit_price) VALUES
(1, 'Premium Dog Food', 'PET-1001', 2, 299.99),
(2, 'Cat Scratching Post', 'PET-1002', 1, 499.00),
(3, 'Bird Cage', 'PET-1003', 1, 899.00),
(4, 'Fish Tank 50L', 'PET-1004', 1, 1299.00),
(5, 'Rabbit Hutch', 'PET-1005', 2, 799.00),
(6, 'Reptile Heating Lamp', 'PET-1006', 1, 349.00),
(7, 'Automatic Pet Feeder', 'PET-1007', 888, 599.00),
(8, 'Dog Leash (Adjustable)', 'PET-1008', 600, 199.00),
(9, 'Cat Litter Box', 'PET-1009', 1, 299.00),
(10, 'Hamster Wheel', 'PET-1010', 2, 149.00),
(11, 'Pet Shampoo (Aloe Vera)', 'PET-1011', 2, 99.00),
(12, 'Dog Chew Toys (Pack of 3)', 'PET-1012', 4, 249.00),
(13, 'Parrot Perch', 'PET-1013', 1235, 179.00),
(14, 'Pet Carrier (Small)', 'PET-1014', 1, 699.00),
(15, 'Aquarium Filter', 'PET-1015', 800, 499.00),
(16, 'Guinea Pig Hay Feeder', 'PET-1016', 1568, 199.00),
(17, 'Cat Tree Tower', 'PET-1017', 1, 1299.00),
(18, 'Dog Training Clicker', 'PET-1018', 900, 79.00),
(19, 'Pet Cooling Mat', 'PET-1019', 2000, 399.00),
(20, 'Turtle Dock', 'PET-1020', 100, 259.00);

INSERT INTO messages (sender_id, receiver_id, parent_message_id, content) VALUES
(1, 2, NULL, 'Lorem ipsum dolor sit amet.'),
(2, 1, 1, 'Consectetur adipiscing elit.'),
(1, 2, 2, 'Sed do eiusmod tempor incididunt ut labore.'),
(3, 4, NULL, 'Ut enim ad minim veniam.'),
(4, 3, 4, 'Quis nostrud exercitation ullamco laboris nisi.'),
(5, 6, NULL, 'Duis aute irure dolor in reprehenderit.'),
(6, 5, 6, 'Excepteur sint occaecat cupidatat non proident.'),
(7, 8, NULL, 'Sunt in culpa qui officia deserunt mollit anim id est laborum.'),
(8, 7, 8, 'Neque porro quisquam est qui dolorem ipsum quia dolor sit amet.'),
(9, 10, NULL, 'At vero eos et accusamus et iusto odio dignissimos.'),
(10, 9, 10, 'Blanditiis praesentium voluptatum deleniti atque corrupti.');