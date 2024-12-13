#Main file for Finnhub API & Kafka integration
import os
import ast
import json
import websocket
from utils.functions import *
#proper class that ingests upcoming messages from Finnhub websocket into Kafka
class FinnhubProducer:
    
    def __init__(self):
        
        print('Environment:')
        for k, v in os.environ.items():
            print(f'{k}={v}')

        self.finnhub_client = load_client(os.environ['FINNHUB_API_TOKEN'])
        self.producer = load_producer(f"{os.environ['KAFKA_SERVER']}:{os.environ['KAFKA_PORT']}")
        self.avro_schema = load_avro_schema('src/schemas/trades.avsc')
        self.tickers = ast.literal_eval(os.environ['FINNHUB_STOCKS_TICKERS'])
        self.validate = os.environ['FINNHUB_VALIDATE_TICKERS']

        websocket.enableTrace(True)
        self.ws = websocket.WebSocketApp(f'wss://ws.finnhub.io?token={os.environ["FINNHUB_API_TOKEN"]}',
                              on_message = self.on_message,
                              on_error = self.on_error,
                              on_close = self.on_close)
        self.ws.on_open = self.on_open
        self.ws.run_forever()

    def on_message(self, ws, message):
        try:
            # Giải mã tin nhắn JSON
            message = json.loads(message)

            # Kiểm tra sự tồn tại của các trường cần thiết
            if 'data' in message and 'type' in message:
                avro_message = avro_encode(
                    {
                        'data': message['data'],
                        'type': message['type']
                    }, 
                    self.avro_schema
                )
                # Gửi thông điệp đã mã hóa tới Kafka
                self.producer.send(os.environ['KAFKA_TOPIC_NAME'], avro_message)
            else:
                print("Received message missing 'data' or 'type':", message)

        except json.JSONDecodeError as e:
            print("Error decoding JSON:", e)
        except KeyError as e:
            print(f"Key error: {e} not found in the message.")
        except Exception as e:
            print("An unexpected error occurred:", e)


    def on_error(self, ws, error):
        print(error)

    def on_close(self, ws):
        print("### closed ###")

    def on_open(self, ws):
        for ticker in self.tickers:
            if self.validate=="1":
                if(ticker_validator(self.finnhub_client,ticker)==True):
                    message = {"type": "subscribe", "symbol": ticker}
                self.ws.send(json.dumps(message))  # Ensure it's a valid JSON string
                print(f'Subscription for {ticker} succeeded')
            else:
                print(f'Subscription for {ticker} failed - ticker not found')
        else:
            # If validation is not enabled, send the subscription message without validation
            message = {"type": "subscribe", "symbol": ticker}
            self.ws.send(json.dumps(message))  # Ensure it's a valid JSON string

if __name__ == "__main__":
    FinnhubProducer()