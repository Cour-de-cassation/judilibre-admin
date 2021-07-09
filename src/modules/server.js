require('./env');
const path = require('path');
const express = require('express');
const { RateLimiterMemory } = require('rate-limiter-flexible');
const rateLimiter = new RateLimiterMemory({
  points: 10,
  duration: 1,
  blockDuration: 5 * 60,
});
const rateLimiterMiddleware = (req, res, next) => {
  rateLimiter
    .consume(req.ip)
    .then((rateLimiterRes) => {
      res.setHeader('X-RateLimit-Limit', rateLimiter.points);
      res.setHeader('X-RateLimit-Remaining', rateLimiterRes.remainingPoints);
      next();
    })
    .catch((rateLimiterRes) => {
      res.setHeader('Retry-After', rateLimiterRes.msBeforeNext / 1000);
      res.setHeader('X-RateLimit-Limit', rateLimiter.points);
      res.setHeader('X-RateLimit-Remaining', rateLimiterRes.remainingPoints);
      res.setHeader('X-RateLimit-Reset', new Date(Date.now() + rateLimiterRes.msBeforeNext));
      if (rateLimiterRes.isFirstInDuration) {
        res.status(429).send('Too Many Requests');
      } else {
        res.status(423).send('Locked');
      }
    });
};

class Server {
  constructor() {
    this.app = express();
    const basicAuth = require('express-basic-auth');
    this.app.use(express.json({ limit: '50mb' }));
    this.app.use(express.urlencoded({ extended: true }));
    this.app.use(rateLimiterMiddleware);
    this.app.use((req, res, next) => {
      res.setHeader('X-Content-Type-Options', 'nosniff');
      res.setHeader('X-Frame-Options', 'deny');
      res.setHeader('Content-Security-Policy', "default-src 'none'");
      next();
    });
    this.app.use(express.static(path.join(__dirname, '..', '..', 'public')));
    this.app.use((err, req, res, next) => {
      if (err instanceof SyntaxError && err.status === 400 && 'body' in err) {
        return res
          .status(400)
          .json({ route: `${req.method} ${req.path}`, errors: [{ msg: 'Bad request.', err: err.message }] });
      }
      next();
    });
    this.app.use(
      basicAuth({
        users: { admin: process.env.HTTP_PASSWD },
      }),
    );
    this.app.use(require(path.join(__dirname, '..', 'api')));
    this.started = false;
  }

  start() {
    if (this.started === false) {
      this.started = true;
      this.app.listen(process.env.API_PORT, () => {
        console.log(`${process.env.APP_ID}.Server: Start server on port ${process.env.API_PORT}.`);
      });
    } else {
      throw new Error(`${process.env.APP_ID}.Server: Server already started.`);
    }
  }
}

module.exports = new Server();
