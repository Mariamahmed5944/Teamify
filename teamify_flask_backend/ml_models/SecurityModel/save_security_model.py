import pickle
import pandas as pd
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler

# 1. Load dataset (حطي اسم الملف الصح عندك)
df = pd.read_csv("teamify_login_logs_final.csv")

# 2. خدي الأرقام بس
X = df.select_dtypes(include=['number'])

# 3. scaling
scaler = StandardScaler()
X_scaled = scaler.fit_transform(X)

# 4. training model
model = IsolationForest(random_state=42)
model.fit(X_scaled)

# 5. save model
bundle = {
    "model": model,
    "scaler": scaler
}

with open("security_model.pkl", "wb") as f:
    pickle.dump(bundle, f)

print("Security model saved ✅")