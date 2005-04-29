//#include "stdlib.h"
#include "binaryheap.h"

typedef struct 
{
  int pos;
  long key;
} elem_t;



int order (elem_t *a, elem_t *b) 
{
  if (a->key == b->key) return 0;
  if (a->key < b->key) return -1;
  return 1;
}

void newpos (elem_t *a, unsigned long pos)
{
  return;
}

void setkey (elem_t *a, long newkey)
{
  a->key = newkey;
  return;
}

DECLARE_BINARYHEAP(test,elem_t,long);

DEFINE_BINARYMAP(test,order,newpos,setkey);

int main(int argc, char **argv)
{
  int i, n;
  test_binaryheap_t heap;
  test_heapinit(&heap);
  elem_t tmp;
  for (i=1;i<argc;i++) 
  {
    sscanf(argv[i], "%d", &n);
    tmp.pos = i;
    test_heapinsert(&heap, tmp, n);
  }
  while (test_heapextractmin(&heap, &tmp) != heap_UNDERFLOW)
  {
    printf ("%d ", tmp.pos);
  }
  printf("\n");
  return 0;
}