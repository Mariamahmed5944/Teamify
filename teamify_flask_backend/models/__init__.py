from flask_sqlalchemy import SQLAlchemy
from flask_sqlalchemy.model import Model


class BaseModel(Model):
    """Shared SQLAlchemy base so keyword constructors type-check under Pyright."""

    def __init__(self, **kwargs):
        super().__init__(**kwargs)


db = SQLAlchemy(model_class=BaseModel)
