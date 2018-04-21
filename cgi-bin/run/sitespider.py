from sqlalchemy import create_engine
from sqlalchemy import Table, Column, Integer, String, MetaData, ForeignKey
from sqlalchemy.orm import mapper
from sqlalchemy.orm import relation
from sqlalchemy.orm import sessionmaker

engine = create_engine('sqlite:///../sqlite-db/site_spider.db', echo=False)
#engine = create_engine('sqlite:///:memory:', echo=True)
Session = sessionmaker(bind=engine, autoflush=True, transactional=True)

metadata = MetaData()
sites_table = Table('sites', metadata,
		    Column('id', Integer, primary_key=True))

documents_table = Table('documents', metadata,
			Column('id', Integer, primary_key=True),
			Column('site_id', Integer, ForeignKey('sites.id')),
			Column('url', String(40)),
			Column('checksum', String(40)))

urls_table = Table('urls', metadata,
		   Column('id', Integer, primary_key=True),
		   Column('site_id', Integer, ForeignKey('sites.id')),
		   Column('location', String(40)),
		   Column('status', Integer))

sentences_table = Table('sentences', metadata,
			Column('id', Integer, primary_key=True),
			Column('document_id', Integer, ForeignKey('documents.id')),
			Column('checksum', String(40)),
			Column('wordcount', Integer))

class Site(object):
	def __init__(self):
		return
	
	def __repr__(self):
		return "<Site.%d>" % (self.id)
	
class Document(object):
	def __init__(self, url):
		self.url = url
		
class Sentence(object):
	def __init__(self):
		return

class Url(object):
	def __init__(self):
		return
mapper(Sentence, sentences_table)
mapper(Document, documents_table, properties={ 'sentences':relation(Sentence, backref='document')})
mapper(Url, urls_table)
mapper(Site, documents_table, properties={ 'documents':relation(Document, backref='site'), 'urls':relation(Url, backref='site')})


