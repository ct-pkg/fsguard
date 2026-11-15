#include <stdlib.h>

int main(void) {
    char *p = malloc(16);
    if (p == NULL) {
        return 2;
    }
    free(p);
    p[0] = 'x';
    return 0;
}
