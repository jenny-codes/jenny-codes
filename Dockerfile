FROM ruby:3.0.2-alpine
WORKDIR /workdir

# RUN bundle install
# bundler
COPY Gemfile Gemfile.lock ./
RUN apk -U add --no-cache --virtual .build-dependencies-bundler \
  git gcc g++ make cmake \
  libxml2-dev libxslt-dev libressl-dev postgresql-dev && \
  BUNDLE_JOBS=8 bundle install && \
  apk del .build-dependencies-bundler

# runtime
RUN apk -U add --no-cache \
  libcurl nodejs libxslt postgresql-libs \
  libjpeg-turbo-utils

COPY . .

EXPOSE 3000

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
