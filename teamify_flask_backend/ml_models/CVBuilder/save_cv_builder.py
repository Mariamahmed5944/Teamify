import pickle
from cv_builder_model import CVBuilder

builder = CVBuilder()

with open("cv_builder.pkl", "wb") as f:
    pickle.dump(builder, f)

print("CV Builder saved ✅")