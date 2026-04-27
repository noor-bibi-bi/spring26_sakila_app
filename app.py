from flask import Flask, render_template, request, flash
import pymysql
from config import Config

app = Flask(__name__)
app.config.from_object(Config)


def get_db_connection():
    return pymysql.connect(
        host=app.config["MYSQL_HOST"],
        user=app.config["MYSQL_USER"],
        password=app.config["MYSQL_PASSWORD"],
        database=app.config["MYSQL_DB"],
        cursorclass=pymysql.cursors.DictCursor,
    )


@app.route("/")
def dashboard():
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            cur.execute("SELECT COUNT(*) as total FROM film")
            total_films = cur.fetchone()["total"]

            cur.execute("SELECT COUNT(*) as total FROM actor")
            total_actors = cur.fetchone()["total"]

            cur.execute("SELECT COUNT(*) as total FROM customer")
            total_customers = cur.fetchone()["total"]

            cur.execute(
                "SELECT COUNT(*) as total FROM rental "
                "WHERE return_date IS NULL"
            )
            active_rentals = cur.fetchone()["total"]

            cur.execute("""
                SELECT SUM(amount) as total_revenue,
                       AVG(amount) as avg_rental_price,
                       COUNT(*) as total_transactions
                FROM payment
                WHERE payment_date >= DATE_SUB(NOW(), INTERVAL 30 DAY)
            """)
            revenue_stats = cur.fetchone()

            cur.execute("""
                SELECT r.rental_id, f.title, c.first_name, c.last_name,
                       r.rental_date
                FROM rental r
                JOIN inventory i ON r.inventory_id = i.inventory_id
                JOIN film f ON i.film_id = f.film_id
                JOIN customer c ON r.customer_id = c.customer_id
                ORDER BY r.rental_date DESC
                LIMIT 10
            """)
            recent_rentals = cur.fetchall()

            cur.execute("""
                SELECT f.title, COUNT(r.rental_id) as rental_count
                FROM film f
                JOIN inventory i ON f.film_id = i.film_id
                JOIN rental r ON i.inventory_id = r.inventory_id
                GROUP BY f.film_id, f.title
                ORDER BY rental_count DESC
                LIMIT 10
            """)
            popular_films = cur.fetchall()

            cur.execute("""
                SELECT s.store_id, a.address, a.district, ci.city, co.country,
                       (SELECT COUNT(*) FROM customer c
                        WHERE c.store_id = s.store_id) as customer_count,
                       (SELECT COUNT(*) FROM inventory i
                        WHERE i.store_id = s.store_id) as inventory_count
                FROM store s
                JOIN address a ON s.address_id = a.address_id
                JOIN city ci ON a.city_id = ci.city_id
                JOIN country co ON ci.country_id = co.country_id
            """)
            store_stats = cur.fetchall()

        conn.close()

        return render_template(
            "dashboard.html",
            total_films=total_films,
            total_actors=total_actors,
            total_customers=total_customers,
            active_rentals=active_rentals,
            revenue_stats=revenue_stats,
            recent_rentals=recent_rentals,
            popular_films=popular_films,
            store_stats=store_stats,
        )

    except Exception as e:
        flash(f"Error loading dashboard: {str(e)}", "error")
        return render_template(
            "dashboard.html",
            total_films=0,
            total_actors=0,
            total_customers=0,
            active_rentals=0,
            revenue_stats={
                "total_revenue": 0,
                "avg_rental_price": 0,
                "total_transactions": 0,
            },
            recent_rentals=[],
            popular_films=[],
            store_stats=[],
        )


@app.route("/films")
def films():
    page = request.args.get("page", 1, type=int)
    per_page = 20
    search = request.args.get("search", "")
    category = request.args.get("category", "")
    rating = request.args.get("rating", "")
    min_year = request.args.get("min_year", "")
    max_year = request.args.get("max_year", "")

    try:
        conn = get_db_connection()
        with conn.cursor() as cur:

            query = """
                SELECT f.film_id, f.title, f.release_year, f.rental_rate,
                       f.length, f.rating, c.name as category,
                       COUNT(r.rental_id) as rental_count,
                       l.name as language_name
                FROM film f
                LEFT JOIN film_category fc ON f.film_id = fc.film_id
                LEFT JOIN category c ON fc.category_id = c.category_id
                LEFT JOIN inventory i ON f.film_id = i.film_id
                LEFT JOIN rental r ON i.inventory_id = r.inventory_id
                LEFT JOIN language l ON f.language_id = l.language_id
            """

            where_conditions = []
            params = []

            if search:
                where_conditions.append(
                    "(f.title LIKE %s OR f.description LIKE %s)"
                )
                params.extend([f"%{search}%", f"%{search}%"])

            if category:
                where_conditions.append("c.name = %s")
                params.append(category)

            if rating:
                where_conditions.append("f.rating = %s")
                params.append(rating)

            if min_year:
                where_conditions.append("f.release_year >= %s")
                params.append(min_year)

            if max_year:
                where_conditions.append("f.release_year <= %s")
                params.append(max_year)

            if where_conditions:
                query += " WHERE " + " AND ".join(where_conditions)

            query += """
                GROUP BY f.film_id, f.title, f.release_year,
                         f.rental_rate, f.length, f.rating,
                         c.name, l.name
                ORDER BY f.title
            """

            count_query = """
                SELECT COUNT(DISTINCT f.film_id) as total
                FROM film f
                LEFT JOIN film_category fc ON f.film_id = fc.film_id
                LEFT JOIN category c ON fc.category_id = c.category_id
            """

            if where_conditions:
                count_query += " WHERE " + " AND ".join(where_conditions)

            cur.execute(count_query, params)
            total = cur.fetchone()["total"]

            query += " LIMIT %s OFFSET %s"
            params.extend([per_page, (page - 1) * per_page])

            cur.execute(query, params)
            films = cur.fetchall()

        conn.close()

        total_pages = (total + per_page - 1) // per_page

        return render_template(
            "films.html",
            films=films,
            page=page,
            total_pages=total_pages,
            total=total,
        )

    except Exception as e:
        flash(f"Error fetching films: {str(e)}", "error")
        return render_template("films.html", films=[])


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0")
