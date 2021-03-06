# col2vcham
A simple program to parse the output of a Columbus
MRCI calculation, extract the parameters of a LVC
Hamiltonian, and output these in a format that can be
used directly with the VCHFIT and MCTDH codes.

# Input
The code is command line driven and only requires two keyword pairs:

-f freqfile, where freqfile is the name of a quantum chemistry output
             file containing the normal modes and frequencies

-d qcfile,   where qcfile is the path to the file or directory
             containing the output of the coupling coefficient
	     calculation

(i.e., col2vcham -f freqfile -d qcfile)

# Output
guess.dat - a file containing the 1st-order parameters of the LVC
            Hamiltonian in a format that can be used directly in a
            subsequent VCHFIT calculation

lvc.op    - an MCTDH operator file corresponding to the LVC
            Hamiltonian
