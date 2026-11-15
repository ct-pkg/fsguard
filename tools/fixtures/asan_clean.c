#include <stdlib.h>

int main(void) {
    char *p = malloc(16);
    if (p == NULL) {
        return 2;
    }
    p[0] = 'x';
    free(p);
    return 0;
}
