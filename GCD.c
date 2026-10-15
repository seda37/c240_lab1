#include <stdio.h>
int a = 54, b = 48;
int gcd(int a, int b){
    
    while(b != 0){
        int r = a%b;
        a = b;
        b = r;
    }
    return a;
}

int main(void){
    int res = gcd(a, b);
    printf("GCD of %d and %d is %d\n", a, b, res);
    return 0;
}