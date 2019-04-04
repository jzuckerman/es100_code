from sklearn.datasets import fetch_20newsgroups
import gensim
from gensim.utils import simple_preprocess
from gensim.parsing.preprocessing import STOPWORDS
from nltk.stem import WordNetLemmatizer, SnowballStemmer
from nltk.stem.porter import *
import numpy as np
import nltk
import pandas as pd
import os

np.random.seed(400)
newsgroups_train = fetch_20newsgroups(subset='train')

stemmer = SnowballStemmer("english")
infile  = "preprocessed.txt.npy"
outfile = "preprocessed.txt"

def lemmatize_stemming(text):
    return stemmer.stem(WordNetLemmatizer().lemmatize(text, pos='v'))

def preprocess(text):
	result=[]
	for token in gensim.utils.simple_preprocess(text) :
	    if token not in gensim.parsing.preprocessing.STOPWORDS and len(token) > 3:
	        result.append(lemmatize_stemming(token))
	        
	return result

try: 
	processed_docs = np.load(infile)
except IOError: 
	print("preprocessing...")
	processed_docs = []

	for doc in newsgroups_train.data:
	    processed_docs.append(preprocess(doc))

	np.save(outfile, processed_docs)

word_indeces = dict()

index = 0 
max_count = 0
num_topics = 1024
num_words = 16004

num_docs = 1024

# topics = open(os.path.join('../init/', 'topic.coe'), 'w')
# words = open(os.path.join('../init/', 'word.coe'), 'w')
# ndoc = open(os.path.join('../init/', 'ndoc.coe'), 'w')

# nw = open(os.path.join('../init/', 'nw.coe'), 'w')
# nd = open(os.path.join('../init/', 'nd.coe'), 'w')
# nwsum = open(os.path.join('../init/', 'nwsum.coe'), 'w')
# ndsum = open(os.path.join('../init/', 'ndsum.coe'), 'w')
# nw_topic = open(os.path.join('../init/', 'nw_topic.coe'), 'w')
# nd_topic = open(os.path.join('../init/', 'nd_topic.coe'), 'w')

topics = open(os.path.join('./', 'topic.txt'), 'w')
words = open(os.path.join('./', 'word.txt'), 'w')
ndoc = open(os.path.join('./', 'ndoc.txt'), 'w')

nw = open(os.path.join('./', 'nw.txt'), 'w')
nd = open(os.path.join('./', 'nd.txt'), 'w')
nwsum = open(os.path.join('./', 'nwsum.txt'), 'w')
ndsum = open(os.path.join('./', 'ndsum.txt'), 'w')
nw_topic = open(os.path.join('./', 'nw_topic.txt'), 'w')
nd_topic = open(os.path.join('./', 'nd_topic.txt'), 'w')

nwsum_mem = open(os.path.join('../init/', 'nwsum.memh'), 'w')

# topics.write('memory_initialization_radix=16;\n memory_initialization_vector=\n')
# words.write('memory_initialization_radix=16;\n memory_initialization_vector=\n')
# ndoc.write('memory_initialization_radix=16;\n memory_initialization_vector=\n')

# nw.write('memory_initialization_radix=16;\n memory_initialization_vector=\n')
# nd.write('memory_initialization_radix=16;\n memory_initialization_vector=\n')
# nwsum.write('memory_initialization_radix=16;\n memory_initialization_vector=\n')
# ndsum.write('memory_initialization_radix=16;\n memory_initialization_vector=\n')
# nw_topic.write('memory_initialization_radix=16;\n memory_initialization_vector=\n')
# nd_topic.write('memory_initialization_radix=16;\n memory_initialization_vector=\n')

nwsum_arr = np.zeros(num_topics)
nd_arr = np.zeros(num_topics * num_docs)
nw_arr = np.zeros(num_topics * num_words)

nw_topic_arr = np.zeros((num_topics, num_words))
nd_topic_arr = np.zeros((num_topics, num_docs))

doc_count = 0
num_words = 0 


for doc in processed_docs[0:num_docs-1]: 
	length = len(doc)
	ndsum.write("{:08x}\n".format(length))
	for word in doc: 
		
		if not word in word_indeces:
			word_indeces[word] = index
			index += 1

		samp = np.random.multinomial(1, [1.0/float(num_topics)]*num_topics)
		topic = np.argmax(samp)
		topics.write("{:04x}\n".format(topic))
		
		word_index = word_indeces[word]
		words.write("{:04x}\n".format(word_index))
		ndoc.write("{:04x}\n".format(doc_count))

		nd_idx = doc_count * num_topics + topic 
		nw_idx = word_index * num_topics + topic

		nwsum_arr[topic] += 1
		nd_arr[nd_idx] += 1
		nw_arr[nw_idx] += 1
		nw_topic_arr[topic][word_index] += 1
		nd_topic_arr[topic][doc_count] += 1
		num_words += 1

	doc_count += 1

print(index)
print(num_words)

topics.seek(-2, os.SEEK_END)
topics.write(';\n')
words.seek(-2, os.SEEK_END)
words.write(';\n')
ndoc.seek(-2, os.SEEK_END)
ndoc.write(';\n')

np.savetxt(nwsum, [nwsum_arr], fmt='%08x', delimiter='\n')
np.savetxt(nd , [nd_arr], fmt='%08x', delimiter='\n')
np.savetxt(nw, [nw_arr], fmt='%08x', delimiter='\n')
np.savetxt(nw_topic, [nw_topic_arr[0]], fmt='%08x', delimiter='\n')
np.savetxt(nd_topic, [nd_topic_arr[0]], fmt='%08x', delimiter='\n')
np.savetxt(nwsum_mem, [nwsum_arr], fmt='%08x', delimiter='\n')

# nw.seek(-1, os.SEEK_END)
# nw.write(';')
# nd.seek(-1, os.SEEK_END)
# nd.write(';')
# nwsum.seek(-1, os.SEEK_END)
# nwsum.write(';')
# ndsum.seek(-1, os.SEEK_END)
# ndsum.write(';')
# nw_topic.seek(-1, os.SEEK_END)
# nw_topic.write(';')
# nd_topic.seek(-1, os.SEEK_END)
# nd_topic.write(';')

