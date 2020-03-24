# Median filter MIPS Project for Computer Architecture, 4th semester
.data
					.eqv	BUFFER_LEN	49152
	inputBuffer:			.space BUFFER_LEN	# Program reads 48kB blocks of data
	processedBuffer: 		.space BUFFER_LEN	# Buffer for processed bytes
	ImportantFromHeader: 	.space	30		# Buffer for most important information from header
	RestOfMetaData:		.space 200		# Buffer for the rest of metadata
	inputFile:			.space 40		# File to filter
	outputFile:			.space 40		# Where to store the result
	filterWindow:			.space 9		# 3x3 window
	
	welcomeMessage:		.ascii		"Welcome to BMP median filter\n"
					.asciiz	"Specify file to filter:\n"	
	askForOutputFile: 		.asciiz	"Specify output file:\n"
	openErrorMessage:		.asciiz	"Open error! Terminating program...\n"
	readErrorMessage:		.asciiz	"Read error! Terminating program...\n"
	wrongBMPMessage:		.asciiz	"Wrong BMP file! Terminating program...\n"
	notBMPMessage:		.asciiz	"Wrong file format, BMP is required. Terminating program...\n"
	writeErrorMessage:		.asciiz	"Write error! Terminating program...\n"
	
.text
.globl main

	main:
		# Asking for first argument
		li 	$v0, 4
		la 	$a0, welcomeMessage
		syscall
		
		# Getting first argument
		li 	$v0, 8
		la 	$a0, inputFile
		li	$a1, 40
		syscall
		
		# Asking for second argument
		li 	$v0, 4
		la 	$a0, askForOutputFile
		syscall
		
		# Getting second argument
		li 	$v0, 8
		la 	$a0, outputFile
		li 	$a1, 40
		syscall
		
		# Terminating arguments with NULL, no white space is allowed
		
		la	$a0, inputFile
		jal	terminateWithNULL
		
		la	$a0, outputFile
		jal	terminateWithNULL

		# Now arguments are terminated with NULL and can be used to open files
		
		# File descriptors in registers:
		# $t8 - inputFile descriptor
		# $t9 - outputFile descriptor
		
		# Opening inputFile
		li 	$v0, 13
		la 	$a0, inputFile
		li 	$a1, 0
		li 	$a2, 0
		syscall
		
		# $t8 - inputFile descriptor
		move	$t8, $v0
		
		# Checking if opening was successful
		bltz	$t8, openError
		
		# Reading header
		li 	$v0, 14
		move 	$a0, $t8
		la 	$a1, ImportantFromHeader
		li 	$a2, 30
		syscall
		
		# Checking if file was read correctly
		bltz	$v0, readError
		
		# Checking if file is in BMP format
		la	$t0, ImportantFromHeader	# Header start address
		lbu	$t1, ($t0)			# First byte = B in BMP format
		seq 	$t3, $t1, 'B'
		lbu	$t2, 1($t0)			# Second byte = M in BMP format
		seq	$t4, $t2, 'M'
		and	$t3, $t3, $t4			# $t3 = 1 if first two bytes are BM
		beqz	$t3, notBMP			# If $t3 = 0 then it is not BMP
		
		# Checking if file is in right BMP format
		ulhu	$t1, 28($t0)
		bne	$t1, 24, wrongBMP
		
		# Loading offset to pixel table to $s7
		ulw	$s7, 10($t0)
		
		# Reading the rest of metadata
		li 	$v0, 14
		move	$a0, $t8
		la 	$a1, RestOfMetaData
		addiu 	$a2, $s7, -30 		# First 30 bytes were read, now reading the rest up to the pixel table
		syscall
		
		# Checking if file was read correctly
		bltz	$v0, readError
		
		## Writing metadata to the output file
		
		# Opening output file
		li 	$v0, 13
		la 	$a0, outputFile
		li 	$a1, 1				# Open to write
		li	$a2, 0
		syscall
		
		# $t9 - outputFile descriptor
		move	$t9, $v0
		
		# Checking if opening was successful
		bltz	$t9, openError
		
		# Writing header
		li 	$v0, 15
		move 	$a0, $t9
		la 	$a1, ImportantFromHeader
		li 	$a2, 30
		syscall
		
		# Checking if writing was successful
		bltz	$v0, writeError
		
		# Writing the rest of metadata
		li 	$v0, 15
		move	$a0, $t9
		addiu 	$a2, $s7, -30 		# First 30 bytes were written, now writing the rest up to the pixel table
		la 	$a1, RestOfMetaData
		syscall
		
		# Checking if writing was successful
		bltz	$v0, writeError
		
		# Placing some important information in registers
		ulw	$s6, 18($t0)			# Placing width in pixels in $s6
		ulw	$s5, 22($t0)			# Placing height in pixels in $s5
		
		mul 	$s6, $s6, 3			# $s6 now contains width in bytes
		
		# Calculating padding
		and 	$t2, $s6, 3			# $t2 = 4 - padding(last 2 bits: 0, 1, 2 or 3)
		li 	$t1, 4				# $t1 = size of word
		beqz	$t2, calculateRest		# If padding is 0 then $t2 is 0(remainder must be 0 then)
		subu 	$s4, $t1, $t2			# $s4 = padding
		
	calculateRest:
		li	$t1, BUFFER_LEN
		addu	$s6, $s6, $s4			# $s6 = width + padding in bytes
		div	$t1, $s6			# In Lo is how many rows can be read in one go to the buffer
		mflo	$s3				# Storing it in $s3
		mul 	$t6, $s3, $s6  		# How many bytes can be read in one go
		mul	$t7, $s6, $s5			# $t7 = size of bitmap data(including padding)
		
		## Preparing useful values for filtering
		
		li	$s2, 1				# which row is being processed
		subu	$s5, $s6, $s4			# width without padding in $s5
		li	$s7, 0				# which byte in row is being processed
		li	$s4, 0				# counter of processed bytes
		la	$s0, inputBuffer		# Placing address to the input buffer in $s0
		la	$s1, processedBuffer		# Placing address to the processed buffer in $s1
		
		# Initial input buffer filling
		li	$v0, 14
		move	$a0, $t8
		la	$a1, ($s0)
		move	$a2, $t6			# reading nr_of_rows_in_buffer * row_length bytes
		syscall
		
		# Registers contain:
		# $t9 - outputFile descriptor
		# $t8 - inputfile descriptor
		# $t7 - size of bitmap data
		# $t6 - number of bytes that can be read to buffer in one go
		# $t5 - address of filterWindow
		#
		# $s7 - byte counter(which byte in row is being processed)
		# $s6 - width with padding in bytes
		# $s5 - width without padding in bytes
		# $s4 - amount of processed bytes
		# $s3 - height of buffer
		# $s2 - row counter(which row of buffer is being processed)
		# $s1 - address of processedBuffer
		# $s0 - address of inputBuffer
	
	medianFilter:
		la 	$t5, filterWindow		# Placing filterWindow's address in $t5, reseted on each calculated byte
		addiu	$s7, $s7, 1			# Byte that is being processed
		blt 	$s4, $s5, rewrite		# When processed bytes < bytes in row rewrite first line of file, including padding
		ble	$s7, 3, rewrite		# When leftmost pixel rewrite it
		subiu	$t2, $s5, 2			# $t2 = first byte of the last pixel
		bge	$s7, $t2, rewrite		# When rightmost pixel rewrite it including padding
		subu	$t3, $t7, $s6			# Value in $t3 is max byte that doesn't belong to the last line of the file
		bgt 	$s4, $t3, rewrite		# When processed byte belongs to the last line of file, rewrite that byte
		
		## Special cases
		
		# First row in the buffer
		beq	$s2, 1, firstBufferRow
		
		# Last row in the buffer
		beq	$s2, $s3, lastBufferRow
		
		## Byte is in the middle - no special treatment is needed
		
		jal 	getByteAndAdjacent
		addu	$s0, $s0, $s6			# Moving row up
		jal	getByteAndAdjacent
		subu	$s0, $s0, $s6
		subu	$s0, $s0, $s6			# Moving row down
		jal 	getByteAndAdjacent
		addu 	$s0, $s0, $s6			# Return to the start row
		addiu 	$s0, $s0, 1			# Move to the next byte to be processed
		
		## Window is now filled, it needs to be sorted to find median
		
		# Registers used:
		# $t0 - value to be replaced with
		# $t2 - sorted counter
		# $t3 - condition(is lower)
		# $a0 - points where to put lowest value
		# $a1 - points last element in window
		# $a2 - value to compare
		
	findMedian:
		li	$t2, 0
		la	$a0, filterWindow
		addiu	$a1, $a0, 8
		
	beginning:
		lbu	$t0, ($a0)			# Loading value to $t0
		move	$t5, $a0			# Other movable pointer to search through elements in window
		
	findLower:
		beq	$t2, 5, pickMedian
		beq	$a1, $t5, elementSorted
		lbu	$a2, 1($t5)			# Loading next value
		addiu	$t5, $t5, 1
		slt	$t3, $a2, $t0			# Is next value lower?
		beqz	$t3, findLower		# It isn't
		sb	$a2, ($a0)			# Replacing elements
		sb	$t0, ($t5)
		move 	$t0, $a2			# New element in $t0
		j	findLower
		
	elementSorted:
		addiu	$a0, $a0, 1			# Moving pointer to the next spot
		addiu	$t2, $t2, 1			# Another element sorted
		j	beginning
		
	pickMedian:
		addiu	$s4, $s4, 1			# Another processed byte
		la	$a0, filterWindow
		lbu	$a1, 4($a0)			# Loading median
		sb	$a1, ($s1)			# Storing processed byte to buffer
		addiu	$s1, $s1, 1			# Next free spot in buffer
		j 	medianFilter	

	setParameters:
		beq	$s4, $t7, finished		# When all bytes have been processed
		li	$s7, 0				# Moving to the next row, reseting byte counter
		beq	$s3, $s2, bufferProcessed	# When last line in the buffer was processed
		addiu	$s2, $s2, 1			# Moving to the next row
		j	medianFilter
		
	bufferProcessed:
		li	$s2, 1				# Reseting row counter
		li 	$v0, 15 			# Writing buffer to the output file
		move 	$a0, $t9
		la	$a1, processedBuffer
		move	$a2, $t6			# Writing the exact amount of bytes that were read
		syscall
		la	$s0, inputBuffer		# Reseting pointer to the beginning of the buffer
		la	$s1, processedBuffer		# Reseting pointer to the beginning of the buffer
		j 	medianFilter
		
	finished:
		div 	$t7, $t6			# Hi = how many bytes were in buffer in last iteration
		mfhi	$a2				# $a2 = how many bytes were in buffer in last iteration or 0 if it was full
		bnez	$a2, writeLastPart
		move	$a2, $t6			# When $a2 was 0 then set it to the number of bytes that can be read to buffer in one go
	
	writeLastPart:
		# Writing last chunk of bytes to the output file
		li 	$v0, 15
		move	$a0, $t9
		la	$a1, processedBuffer
		syscall
		
		# Closing output file
		li	$v0, 16
		move	$a0, $t9
		syscall
		
		# Closing input file
		li 	$v0, 16
		move	$a0, $t8
		syscall
		
	exitProgram:
		li	$v0, 10
		syscall

	rewrite:
		lbu	$a3, ($s0)			# Load byte to rewrite
		sb	$a3, ($s1)			# Write it to the output file
		addiu 	$s0, $s0, 1			# Move to the next byte to be processed
		addiu	$s1, $s1, 1			# next free spot in buffer
		addiu	$s4, $s4, 1			# Another processed byte
		beq	$s7, $s6, setParameters	# When last byte of row was processed
		j	medianFilter
		
	firstBufferRow:
		jal 	getByteAndAdjacent
		addu	$s0, $s0, $s6			# Moving to the next row
		jal	getByteAndAdjacent		# Loading higher and his adjacent once
		addu	$t4, $s6, $s6			# $t4 = number of bytes to save to the buffer
		subu	$t3, $t6, $t4			# Offset required to move to the last row
		addu 	$s0, $s0, $t3
		jal	getByteAndAdjacent
		subu	$s0, $s0, $t3			# Return to the pre-start row
		subu	$s0, $s0, $s6			# Return to the start row
		addiu 	$s0, $s0, 1			# Move to the next byte to be processed
		subiu	$t2, $s5, 3			# $t4 = last byte of the last processable pixel
		bne	$s7, $t2, findMedian		# After processing first row, last two not refilled rows must be updated(before processing this old rows were needed for filtering)
		# $t3 = also offset where to write those bytes
		li	$v0, 14
		move	$a0, $t8
		la	$a1, inputBuffer($t3)	# address with offset
		move	$a2, $t4			# reading 2 * row_length bytes
		syscall	
		j	findMedian
		
	lastBufferRow:
		subu	$t4, $t6, $s6
		subu	$t4, $t4, $s6			# $t4 = how many bytes to save to the buffer and offset from pre-last row to the first row
		bne	$s7, 4, bufferOk		# When on first non-rewritten byte then refill part of the buffer
		# Only n-2 rows will be replaced in buffer, last two need to stay for correct filter processing
		li	$v0, 14
		move	$a0, $t8
		la	$a1, inputBuffer
		move	$a2, $t4			# reading (nr_of_rows_in_buffer - 2) * row_length bytes
		syscall			
	bufferOk:
		jal 	getByteAndAdjacent
		subu	$s0, $s0, $s6			# Moving to the previous row
		jal	getByteAndAdjacent
		# $t4 = how many bytes subtract to get to the first row
		subu	$s0, $s0, $t4			# Moving to the first row
		jal 	getByteAndAdjacent
		addu 	$s0, $s0, $t4			# Return to the pre-start row		
		addu	$s0, $s0, $s6			# Return to the start row
		addiu	$s0, $s0, 1			# Move to the next byte to be processed
		j	findMedian
		
	terminateWithNULL:
		lbu 	$t1, ($a0)
		addiu	$a0, $a0, 1
		bgt	$t1, 32, terminateWithNULL
		sb 	$zero, -1($a0)
		jr 	$ra
	
	printMessage:
		li 	$v0, 4
		syscall
		jr	$ra
		
	getByteAndAdjacent:
		lbu	$a3, ($s0)			# Load current byte
		sb	$a3, ($t5)			# Store it in window
		addiu 	$s0, $s0, 3			# Move to the right byte of the same color
		lbu 	$a3, ($s0)			# Load that byte
		sb 	$a3, 1($t5) 			# Store it in window
		addiu 	$s0, $s0,-6 			# Move to the left byte of the same color
		lbu 	$a3, ($s0)			# Load that byte
		sb 	$a3, 2($t5) 			# Store it in window
		addiu 	$t5, $t5, 3 			# Move pointer to the next free slot in the window
		addiu 	$s0, $s0, 3			# Return to the start byte
		jr	$ra
		
	openError:
		la	$a0, openErrorMessage
		jal	printMessage
		j	exitProgram
		
	readError:
		la 	$a0, readErrorMessage
		jal	printMessage
		j	exitProgram

	writeError:
		la 	$a0, writeErrorMessage
		jal	printMessage
		j	exitProgram

	notBMP:

		la 	$a0, notBMPMessage
		jal	printMessage
		j	exitProgram

	wrongBMP:
		la 	$a0, wrongBMPMessage
		jal	printMessage
		j	exitProgram
