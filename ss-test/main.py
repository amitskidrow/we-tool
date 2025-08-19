import time
import random

def main():
    while True:
        print(f"Random number: {random.randint(100, 999)}")
        time.sleep(1)

if __name__ == "__main__":
    main()
