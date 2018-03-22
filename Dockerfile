FROM node:8.4

WORKDIR /discovery_news
COPY ./app /discovery_news

CMD ["bash", "-c", "node server"]

