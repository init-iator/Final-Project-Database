# Pet Shop Database Management System

This project provides a database management system for a pet shop using MariaDB. It includes Docker configurations for setting up the MariaDB server and client, as well as a Python script to interact with the database.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Setup](#setup)
  - [Docker Setup](#docker-setup)
  - [Python Script Setup](#python-script-setup)
- [Usage](#usage)
- [File Structure](#file-structure)
- [Environment Variables](#environment-variables)
- [Contributing](#contributing)
- [License](#license)

## Prerequisites

- Docker and Docker Compose installed on your machine.
- Python 3.x installed on your machine.
- `mariadb` Python package installed.
- `python-dotenv` Python package installed.

## Setup

### Docker Setup

1. Create a `.env` file in the root directory with the following content:

    ```env
    MARIADB_ROOT_PASSWORD=your_root_password
    ```

2. Start the MariaDB server and client using Docker Compose:

    ```sh
    docker-compose up -d
    ```

3. The MariaDB server will be accessible on port `3306`. The database will be initialized using the `init.sql` script.

### Python Script Setup

1. Create a `credentials.env` file in the root directory with the following content:

    ```env
    DB_USER=your_db_user
    DB_PASSWORD=your_db_password
    DB_HOST=127.0.0.1
    DB_DATABASE=your_db_name
    ```

2. Install the required Python packages:

    ```sh
    pip install mariadb python-dotenv
    ```

3. Run the Python script to interact with the database:

    ```sh
    python pet_db.py
    ```

## Usage

1. Start the Docker containers:

    ```sh
    docker-compose up -d
    ```

2. Run the Python script:

    ```sh
    python pet_db.py
    ```

3. Follow the prompts in the script to select a warehouse and check order fulfillment.

## File Structure

- `docker-compose.yml`: Docker Compose configuration file.
- `.env`: Environment variables for Docker.
- `credentials.env`: Environment variables for the Python script.
- `init.sql`: SQL script to initialize the database.
- `pet_db.py`: Python script to interact with the database.
- `pet_db/pet_shop_db.sql`: SQL script to create the pet shop database schema.

## Environment Variables

### `.env` (Docker)

- `MARIADB_ROOT_PASSWORD`: Root password for the MariaDB server.

### `credentials.env` (Python Script)

- `DB_USER`: Database user.
- `DB_PASSWORD`: Database password.
- `DB_HOST`: Database host (default is `localhost(windows) or 127.0.0.1(linux/windows`).
- `DB_DATABASE`: Database name.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## License

This project is licensed under the MIT License.
