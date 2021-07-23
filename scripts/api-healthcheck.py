#!/usr/bin/python3
import time
import json
import requests
import telebot

BOT_TG_ID = "-481421264"
BOT_KEY = '1789090059:AAGQ6ZJ2i__bdR_R47WVNJcHi_vDu7deuQg'

bot = telebot.TeleBot(BOT_KEY)

def main():
    while(True):
        try:
            response = requests.get("https://api.bzx.network/v1/farming-pools-info?networks=bsc,eth,polygon")
            print(response.status_code)
            if(response.status_code != 200):
               bot.send_message(BOT_TG_ID, f"API response status: {response.status_code}")
        except Exception as e:
            bot.send_message(BOT_TG_ID, f"API is down!")
        print("Sleep 1 min")
        time.sleep(60)