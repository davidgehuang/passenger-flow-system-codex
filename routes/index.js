'use strict';

const express = require('express');
const router = express.Router();

const dashboardController = require('../controllers/dashboardController');
const storeRoutes = require('./storeRoutes');
const deviceRoutes = require('./deviceRoutes');
const flowEventRoutes = require('./flowEventRoutes');
const healthRoutes = require('./healthRoutes');
const migrationRoutes = require('./migrationRoutes');

router.get('/', dashboardController.index);
router.use('/stores', storeRoutes);
router.use('/devices', deviceRoutes);
router.use('/flow-events', flowEventRoutes);
router.use(healthRoutes);
router.use(migrationRoutes);

module.exports = router;
