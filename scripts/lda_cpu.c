#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>

#define TOKENS 125528
#define WORDS 16004
#define DOCS 1024
#define TOPICS 1024
#define beta 0.1
#define alpha 0.5
#define TRIALS 500

float Kalpha = TOPICS * alpha;
float Vbeta = WORDS * beta; 

int words[TOKENS];
int topics[TOKENS];
unsigned int ndsum[DOCS];
unsigned int nwsum[TOPICS];
unsigned int nw[TOPICS*WORDS];
unsigned int nd[TOPICS*DOCS];

int sample_word(int word, int doc, int mode);
struct timespec diff(struct timespec start, struct timespec end);

int main (void) {
	srand48(122796);
	FILE *topics_p, *words_p, *ndsum_p, *nd_p, *nwsum_p, *nw_p;

	topics_p = fopen("topic.txt", "r");
	words_p = fopen("word.txt", "r");

	for (int i = 0; i < TOKENS; i++){
		fscanf(topics_p, "%x\n", &topics[i]);
		fscanf(words_p, "%x\n", &words[i]);
	}

	fclose(topics_p);
	fclose(words_p);


	ndsum_p = fopen("ndsum.txt", "r");
	nd_p = fopen("nd.txt", "r");

	for (int i = 0; i < DOCS; i++){
		fscanf(ndsum_p, "%x\n", &ndsum[i]);
		for (int j = 0; j < TOPICS; j++){
			fscanf(nd_p, "%x\n", &nd[i*TOPICS + j]);
		}
	}

	fclose(ndsum_p);
	fclose(nd_p);

	nwsum_p = fopen("nwsum.txt", "r");
	nw_p = fopen("nw.txt", "r");

	for (int i = 0; i < TOPICS; i++){
		fscanf(nwsum_p, "%x\n", &nwsum[i]);
		for (int j = 0; j < WORDS; j++){
			fscanf(nw_p, "%x\n", &nw[j*TOPICS + i]);
		}
	}

	fclose(nwsum_p);
	fclose(nw_p);

	int word, topic, doc, word_in_doc, new_topic, doc_length; 
	word_in_doc = doc = 0;
	clock_t t; 
	for (int mode = 0; mode < 1; mode ++) {
		t = clock();
		for (int trial = 0; trial < TRIALS; trial ++) {
			for (int i = 0; i < TOKENS; i++){
				struct timespec time1, time2, timediff;
		    	clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &time1);

				word = words[i];
				topic = topics[i];
				doc_length = ndsum[doc];
				
				if (ndsum[doc] > 0)
					ndsum[doc]--;
				if (nd[doc*TOPICS + topic] > 0)
					nd[doc*TOPICS + topic]--;
				if (nwsum[topic] > 0)
					nwsum[topic]--;
				if (nw[word*TOPICS + topic] > 0)
				nw[word*TOPICS + topic]--;

				new_topic = sample_word(word, doc, mode);
				ndsum[doc]++;
				nd[doc*TOPICS + new_topic]++;
				nwsum[topic]++;
				nw[word*TOPICS + new_topic]++;
				
				if (word_in_doc == doc_length - 1){
					word_in_doc = 0; 
					doc++;
				}
				else{
					word_in_doc++;
				}
				clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &time2);

				timediff = diff(time1, time2); 
			}
		}
		t = clock() - t;
		double time_taken = ((double)t)/CLOCKS_PER_SEC; // in seconds 
		printf("computation with mode %d took %.9f seconds\n", mode, ((time_taken / TRIALS) / TOKENS));
	}
	

}

int sample_word(int word, int doc, int mode){
	unsigned int ndsum_cur, nd_cur, nw_cur, nwsum_cur;
	float p, cum_p, add0 , add1, add2, add3, mul0, mul1;
	cum_p = 0; 
	float cum_probs[TOPICS];
	for (int i = 0; i < TOPICS; i++){
		ndsum_cur = ndsum[doc]; 
		nd_cur = nd[doc*TOPICS + i];
		nwsum_cur = nwsum[i];
		nw_cur = nw[word*TOPICS + i];

		add0 = nw_cur + beta; 
		add1 = nwsum_cur + Vbeta; 
		add2 = nd_cur + alpha; 
		add3 = ndsum_cur + Kalpha;
		mul0 = add0 * add2; 
		mul1 = add1 * add3;
		p = mul0 / mul1; 

		cum_p += p; 
		cum_probs[i] = cum_p;
	}

	float rand;
	if (mode == 0) rand = drand48();
	else if (mode == 1) rand = 0.0; 
	else rand = 1.0; 
	float randnorm = rand * cum_p;

	int index;
	for (index = 0; index < TOPICS; index++){
		if (cum_probs[index] > randnorm)
			break;
	}

	return index;
}

struct timespec diff(struct timespec start, struct timespec end)
{
	struct timespec temp;
	if ((end.tv_nsec-start.tv_nsec)<0) {
		temp.tv_sec = end.tv_sec-start.tv_sec-1;
		temp.tv_nsec = 1000000000+end.tv_nsec-start.tv_nsec;
	} else {
		temp.tv_sec = end.tv_sec-start.tv_sec;
		temp.tv_nsec = end.tv_nsec-start.tv_nsec;
	}
	return temp;
}