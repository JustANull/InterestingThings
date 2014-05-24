local ffi = assert(require('ffi'))

if ffi.os == 'OSX' then
	if ffi.arch == 'x86' then
		ffi.cdef([[
			static const int __PTHREAD_SIZE__ =           	596;
			static const int __PTHREAD_ATTR_SIZE__ =      	36;
			static const int __PTHREAD_MUTEXATTR_SIZE__ = 	8;
			static const int __PTHREAD_MUTEX_SIZE__ =     	40;
			static const int __PTHREAD_CONDATTR_SIZE__ =  	4;
			static const int __PTHREAD_COND_SIZE__ =      	24;
			static const int __PTHREAD_ONCE_SIZE__ =      	4;
			static const int __PTHREAD_RWLOCK_SIZE__ =    	124;
			static const int __PTHREAD_RWLOCKATTR_SIZE__ =	12;
		]])
	elseif ffi.arch == 'x64' then
		ffi.cdef([[
			static const int __PTHREAD_SIZE__ =           	1168;
			static const int __PTHREAD_ATTR_SIZE__ =      	56;
			static const int __PTHREAD_MUTEXATTR_SIZE__ = 	8;
			static const int __PTHREAD_MUTEX_SIZE__ =     	56;
			static const int __PTHREAD_CONDATTR_SIZE__ =  	8;
			static const int __PTHREAD_COND_SIZE__ =      	40;
			static const int __PTHREAD_ONCE_SIZE__ =      	8;
			static const int __PTHREAD_RWLOCK_SIZE__ =    	192;
			static const int __PTHREAD_RWLOCKATTR_SIZE__ =	16;
		]])
	else
		error('unsupported')
	end

	ffi.cdef([[
		struct __darwin_pthread_handler_rec {
			void                               	(*__routine)(void *);
			void                               	*__arg;
			struct __darwin_pthread_handler_rec	*__next;
		};
		struct _opaque_pthread_attr_t {
			long __sig;
			char __opaque[__PTHREAD_ATTR_SIZE__];
		};
		struct _opaque_pthread_cond_t {
			long __sig;
			char __opaque[__PTHREAD_COND_SIZE__];
		};
		struct _opaque_pthread_condattr_t {
			long __sig;
			char __opaque[__PTHREAD_CONDATTR_SIZE__];
		};
		struct _opaque_pthread_mutex_t {
			long __sig;
			char __opaque[__PTHREAD_MUTEX_SIZE__];
		};
		struct _opaque_pthread_mutexattr_t {
			long __sig;
			char __opaque[__PTHREAD_MUTEXATTR_SIZE__];
		};
		struct _opaque_pthread_once_t {
			long __sig;
			char __opaque[__PTHREAD_ONCE_SIZE__];
		};
		struct _opaque_pthread_rwlock_t {
			long __sig;
			char __opaque[__PTHREAD_RWLOCK_SIZE__];
		};
		struct _opaque_pthread_rwlockattr_t {
			long __sig;
			char __opaque[__PTHREAD_RWLOCKATTR_SIZE__];
		};
		struct _opaque_pthread_t {
			long __sig;
			struct __darwin_pthread_handler_rec *__cleanup_stack;
			char __opaque[__PTHREAD_SIZE__];
		};

		typedef struct _opaque_pthread_attr_t      	__darwin_pthread_attr_t;
		typedef struct _opaque_pthread_cond_t      	__darwin_pthread_cond_t;
		typedef struct _opaque_pthread_condattr_t  	__darwin_pthread_condattr_t;
		typedef unsigned long                      	__darwin_pthread_key_t;
		typedef struct _opaque_pthread_mutex_t     	__darwin_pthread_mutex_t;
		typedef struct _opaque_pthread_mutexattr_t 	__darwin_pthread_mutexattr_t;
		typedef struct _opaque_pthread_once_t      	__darwin_pthread_once_t;
		typedef struct _opaque_pthread_rwlock_t    	__darwin_pthread_rwlock_t;
		typedef struct _opaque_pthread_rwlockattr_t	__darwin_pthread_rwlockattr_t;
		typedef struct _opaque_pthread_t           	*__darwin_pthread_t;

		typedef __darwin_pthread_attr_t      	pthread_attr_t;
		typedef __darwin_pthread_cond_t      	pthread_cond_t;
		typedef __darwin_pthread_condattr_t  	pthread_condattr_t;
		typedef __darwin_pthread_key_t       	pthread_key_t;
		typedef __darwin_pthread_mutex_t     	pthread_mutex_t;
		typedef __darwin_pthread_mutexattr_t 	pthread_mutexattr_t;
		typedef __darwin_pthread_once_t      	pthread_once_t;
		typedef __darwin_pthread_rwlock_t    	pthread_rwlock_t;
		typedef __darwin_pthread_rwlockattr_t	pthread_rwlockattr_t;
		typedef __darwin_pthread_t           	pthread_t;
	]])
else
	error('unsupported')
end

ffi.cdef([[
	int 	pthread_create(	pthread_t* thread, const pthread_attr_t* attr, void*(*start)(void*), void* arg);
	int 	pthread_join(  	pthread_t thread, void** value_ptr);
	void	pthread_exit(  	void* value);

	int	pthread_mutex_init(   	pthread_mutex_t* mutex, pthread_mutexattr_t* attr);
	int	pthread_mutex_destroy(	pthread_mutex_t* mutex);
	int	pthread_mutex_lock(   	pthread_mutex_t* mutex);
	int	pthread_mutex_trylock(	pthread_mutex_t* mutex);
	int	pthread_mutex_unlock( 	pthread_mutex_t* mutex);
]])
