const { z } = require('zod')
const { idSchema, money } = require('./core')
const text = (max=120) => z.string().trim().min(1).max(max)
const ids = z.array(idSchema).max(100)
const status = z.enum(['draft','published','paused','archived'])
const media = { thumbnailMediaId:idSchema.nullable().optional(), imageMediaIds:ids.optional() }
const dated = { startsAt:z.iso.datetime({offset:true}), endsAt:z.iso.datetime({offset:true}) }
const definitions = {
  packages: { collection:'service_packages', permission:'packages', fields:{
    name:text(), description:text(3000), components:z.array(z.object({ serviceId:idSchema, quantity:z.number().int().min(1).max(20) }).strict()).min(2).max(30),
    pricePaise:money, durationMinutes:z.number().int().min(1).max(1440), ...media, displayOrder:z.number().int().min(0), status,
  }, public:true },
  offers: { collection:'offers', permission:'offers', fields:{
    name:text(), description:text(1000), code:z.string().regex(/^[A-Z0-9_-]{3,24}$/),
    discountType:z.enum(['percentage','fixed']), value:z.number().int().positive().max(Number.MAX_SAFE_INTEGER),
    maximumDiscountPaise:money, minimumOrderPaise:money, totalLimit:z.number().int().positive(),
    perCustomerLimit:z.number().int().positive(), newCustomerOnly:z.boolean(),
    serviceIds:ids, categoryIds:ids, packageIds:ids, ...dated, ...media, status,
  }, public:true },
  banners: { collection:'promotional_banners', permission:'banners', fields:{
    name:text(), subtitle:text(500), audiences:z.array(z.enum(['customer','worker'])).min(1).max(2),
    targetType:z.enum(['service','category','offer','package']).optional(), targetId:idSchema.optional(),
    ...dated, ...media, displayOrder:z.number().int().min(0), status,
  }, public:true },
  'service-areas': { collection:'service_areas', permission:'areas', fields:{
    areaCode:z.string().regex(/^[A-Z0-9_-]{2,40}$/), name:text(), city:text(), state:text(),
    postalCodes:z.array(z.string().regex(/^\d{6}$/)).min(1).max(1000),
    isServiceable:z.boolean(), operatingHours:z.object({
      opens:z.string().regex(/^\d{2}:\d{2}$/), closes:z.string().regex(/^\d{2}:\d{2}$/),
    }).strict().refine(v => v.opens < v.closes), status:z.enum(['active','disabled','archived']),
  }},
  settings: { collection:'app_settings', permission:'settings', fields:{
    key:z.literal('business'), bookingLeadMinutes:z.number().int().min(0).max(43200),
    assignmentTimeoutMinutes:z.number().int().min(1).max(120),
    cancellationNoticeHours:z.number().int().min(0).max(720),
    slotMinutes:z.number().int().min(5).max(240), arrivalOtpRequired:z.literal(true),
    operatingCity:z.literal('Latur'),
    operatingHours:z.object({opens:z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/),closes:z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/)}).strict().refine(v=>v.opens<v.closes).optional(),
    rescheduleNoticeHours:z.number().int().min(0).max(720).optional(),
  }},
  customers: { collection:'customers', permission:'customers', create:false, fields:{
    fullName:text(), email:z.email().max(254).optional(), notes:z.string().max(2000).optional(),
  }, statusValues:['active','suspended'] },
  workers: { collection:'workers', permission:'workers', create:false, fields:{
    fullName:text(), email:z.email().optional(), experienceYears:z.number().min(0).max(80),
    serviceIds:ids, serviceAreaIds:ids, isOnline:z.boolean(),
  }},
  leaves: { collection:'worker_leaves', permission:'workers.leaves', create:false, fields:{}, readOnly:true },
  'booking-events': { collection:'booking_events', permission:'bookings', fields:{}, readOnly:true },
  bookings: { collection:'bookings', permission:'bookings', fields:{}, readOnly:true },
  assignments: { collection:'booking_assignments', permission:'bookings', fields:{}, readOnly:true },
  payments: { collection:'payments', permission:'payments', fields:{}, readOnly:true },
  settlements: { collection:'worker_settlements', permission:'settlements', fields:{}, readOnly:true },
  reviews: { collection:'reviews', permission:'reviews', create:false, fields:{}, statusValues:['visible','hidden'] },
  support: { collection:'support_tickets', permission:'support', fields:{
    subject:text(), category:z.enum(['booking','assignment','payment','quality','other']),
    priority:z.enum(['normal','high','urgent']), bookingId:idSchema.optional(), assignedAdminId:idSchema.nullable().optional(),
  }, statusValues:['open','in_review','resolved'] },
  notifications: { collection:'notifications', permission:'notifications', fields:{}, readOnly:true },
  audit: { collection:'audit_logs', permission:'audit', fields:{}, readOnly:true },
  roles: { collection:'roles', permission:'roles', fields:{
    roleCode:z.enum(['SUPER_ADMIN','ADMIN','OPERATIONS','FINANCE']), roleName:text(),
    permissions:z.array(z.string().regex(/^[a-z.]+$/)).max(200), isActive:z.boolean(),
  }},
}
const safeProjection = { passwordHash:0, refreshTokenHash:0, otpHash:0, tokenHash:0, privateUrl:0, storageKey:0 }
const permissions = Object.freeze([...new Set([
  ...Object.values(definitions).flatMap(d => [d.permission+'.read', ...(d.readOnly ? [] : [d.permission+'.create',d.permission+'.update',d.permission+'.publish',d.permission+'.archive'])]),
  'admins.update','workers.leaves.update','workers.documents.read','workers.approve','workers.reject','workers.suspend','bookings.assign','bookings.cancel',
  'workers.compensation.update','bookings.create','bookings.reschedule','payments.refund','payments.refund.approve','payments.refund.record','payments.reconcile','settlements.approve','reports.read','catalog.media.upload',
  'catalog.categories.read','catalog.categories.create','catalog.categories.update','catalog.categories.publish',
  'catalog.services.read','catalog.services.create','catalog.services.update','catalog.services.publish',
])])
module.exports={ definitions, safeProjection, permissions }
