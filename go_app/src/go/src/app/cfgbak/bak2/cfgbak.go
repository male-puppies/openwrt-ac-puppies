package main

/*
#include <stdio.h>

void sayHi() {
  printf("Hi-------------------------\n");
}
*/
import "C"

func main() {
	C.sayHi()
}