from flask import Flask

app = Flask(__name__)

@app.route('/')
def hello():
    return "<h1>Witaj w Projekcie 1!</h1><p>To jest testowa aplikacja Flask działająca za pośrednictwem Traefik.</p>"

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
