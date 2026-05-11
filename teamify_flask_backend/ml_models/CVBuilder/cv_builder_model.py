class CVBuilder:

    def __init__(self):
        pass

    def extract_features(self, user_data):

        return {
            "skills_count": len(user_data.get("skills", [])),
            "experience_years": user_data.get("experience", 0)
        }

    def generate_cv_data(self, user_data):

        features = self.extract_features(user_data)

        return {
            "name": user_data.get("name"),
            "features": features
        }