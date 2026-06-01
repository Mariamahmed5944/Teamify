from models import db


class SystemSetting(db.Model):
    __tablename__ = 'system_settings'

    key = db.Column(db.String(255), primary_key=True, nullable=False)
    value = db.Column(db.JSON, nullable=False)

    def __init__(self, key, value):
        self.key = key
        self.value = value

    @classmethod
    def get(cls, key, default=None):
        setting = cls.query.filter_by(key=key).first()
        if setting:
            return setting.value
        return default

    @classmethod
    def set(cls, key, value):
        setting = cls.query.filter_by(key=key).first()
        if not setting:
            setting = cls(key=key, value=value)
            db.session.add(setting)
        else:
            setting.value = value
        db.session.commit()
        return setting
