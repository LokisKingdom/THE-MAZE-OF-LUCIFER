extends Node

var unlocked_books = [0]

func unlock_book(book_index: int):
	if book_index in unlocked_books:
		return

	unlocked_books.append(book_index)
	print("NEW BOOK DISCOVERED")
