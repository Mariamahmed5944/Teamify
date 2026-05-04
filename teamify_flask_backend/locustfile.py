import os
import random
import time
from locust import HttpUser, task, between, events

class FlaskAuthUser(HttpUser):
    """
    Locust virtual user that logs in and heavily hits the protected /api/auth/me route 
    to test the JWT decoding and DB querying performance under load.
    """
    # Wait 1 to 3 seconds between tasks
    wait_time = between(1, 3)

    def on_start(self):
        """
        Executed once per virtual user when they spawn.
        We'll dynamically create a unique user to avoid unique constraint errors,
        then log in to capture the JWT token.
        """
        # Generate a unique identity
        self.user_id = f"locust_{int(time.time() * 1000)}_{random.randint(1000, 9999)}"
        self.email = f"{self.user_id}@example.com"
        self.password = "Password123"

        # 1. Register the user
        self.client.post("/api/auth/register", json={
            "display_name": self.user_id,
            "email": self.email,
            "password": self.password,
            "role": "member",
            "user_type": "freelancer"
        }, name="/api/auth/register")

        # 2. Log in to get the JWT access token
        response = self.client.post("/api/auth/login", json={
            "email": self.email,
            "password": self.password
        }, name="/api/auth/login")

        self.token = ""
        if response.status_code == 200:
            self.token = response.json().get("access_token", "")

        # Set up the authorization header for subsequent protected requests
        self.headers = {"Authorization": f"Bearer {self.token}"}

    @task(5)
    def fetch_me_profile(self):
        """
        The main task: heavily query the protected /me endpoint.
        Weight = 5 (happens 5x more often than other tasks).
        """
        if self.token:
            self.client.get("/api/auth/me", headers=self.headers, name="/api/auth/me (GET)")

    @task(1)
    def update_profile(self):
        """
        Less frequent task: update the profile to test DB write concurrency.
        Weight = 1.
        """
        if self.token:
            self.client.patch("/api/auth/me", headers=self.headers, json={
                "availability": random.choice(["Full Time", "Part Time", "Freelance"])
            }, name="/api/auth/me (PATCH)")
