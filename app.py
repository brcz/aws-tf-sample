from flask import Flask, request, jsonify
import time

app = Flask(__name__)

@app.route('/delay', methods=['GET'])
def delay_response():
    delay = request.args.get('delay', default=100, type=int)
    time.sleep(delay)
    return jsonify({'message': f'Delayed response by {delay} seconds'})

@app.route('/')
def hello_world():
    return 'Hello, World!'


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
