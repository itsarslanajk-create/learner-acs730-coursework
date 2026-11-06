# Midterm Practice -- Notes

## Task 5: git hygiene

Deleting the .tfstate file and the hard-coded key in the latest commit does not remove them from the repository, because every earlier commit still contains them and anyone who can clone or browse the history can recover them, so the key must be treated as leaked and revoked or rotated (and the history rewritten if the data itself must be purged).
