from sqlalchemy import create_engine
from sqlalchemy import Table, Column, Integer, String, MetaData, ForeignKey
from sqlalchemy.orm import mapper
from sqlalchemy.orm import sessionmaker

class Language(object):
	def __init__(self):
		return
	
class LanguageCost(object):
	def __init__(self, from_id, to_id, cost_in_cents):
		self.from_id = from_id
		self.to_id = to_id
		self.cost_in_cents = cost_in_cents

def get_session():
	engine = create_engine('sqlite:///../sqlite-db/development/languages.db', echo=False)

	metadata = MetaData()
	sites_table = Table('sites', metadata,
				Column('id', Integer, primary_key=True))

	languages_table = Table('languages', metadata,
							Column('id', Integer, primary_key=True),
							Column('name', String),
							Column('major', Integer))

	language_costs_table = Table('language_costs', metadata,
								 Column('id', Integer, primary_key=True),
								 Column('from_id', Integer),
								 Column('to_id', Integer),
								 Column('cost_in_cents', Integer))

	mapper(Language, languages_table)
	mapper(LanguageCost, language_costs_table)

	lang_Session = sessionmaker(bind=engine, autoflush=True, transactional=True)
	lang_session = lang_Session()
	return lang_session

#lang_query = lang_session.query(Language)

if __name__ == "__main__":
	lang_session = get_session()
	languages = lang_session.query(Language).all()
	for language in languages:
		print "%d: %s"%(language.id, language.name)

	eng = lang_session.query(Language).get(1)
	print "\n%s: %s"%(eng, eng.name)
