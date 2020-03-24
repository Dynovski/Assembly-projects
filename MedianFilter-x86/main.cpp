
#include <stdio.h>
#include <fstream>
#include <iostream>
#include "CImg.h"

#ifdef __cplusplus
extern "C" {
#endif
	int medianFilter(char*, char*, char*);
#ifdef __cplusplus
}
#endif

using namespace std;
using namespace cimg_library;

int main()
{
  char buffer[16];
  char inputFileName[128];
  char outputFileName[128];
  ifstream fin;
  ofstream fout;

  cout << "Enter file to filter: ";
  cin >> inputFileName;

  cout << "Enter result name: ";
  cin >> outputFileName;

  fin.open(inputFileName, ios_base::in);
  if(!fin.is_open())
  {
    cout << "File doesn't exist.\n";
    return 1;
  }

  fin.seekg(0, ios::end);
  int length = fin.tellg();
  fin.seekg(0, ios::beg);

  char* inputFile = new char[length];
  char* outputFile = new char[length];

  fin.read(inputFile, length);
  fin.close();  

  medianFilter(buffer, inputFile, outputFile);

  fout.open(outputFileName, ios_base::out); 

  fout.write(outputFile, length);
  fout.close();   

  CImg<unsigned char> inputFileImage(inputFileName), outputFileImage(outputFileName);
  CImgDisplay inDisplay(inputFileImage,"Before filtering"), outDisplay(outputFileImage,"After filtering");
  while (!inDisplay.is_closed() || !outDisplay.is_closed())
  {
    inDisplay.wait();
    outDisplay.wait();
  }

  delete[] inputFile;
  delete[] outputFile;
  
  return 0;
}
