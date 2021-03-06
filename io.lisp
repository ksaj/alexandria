;; Copyright (c) 2002-2006, Edward Marco Baringer
;; All rights reserved.

(in-package :alexandria)

(defmacro with-open-file* ((stream filespec &key direction element-type
                                   if-exists if-does-not-exist external-format)
                           &body body)
  "Just like WITH-OPEN-FILE, but NIL values in the keyword arguments mean to use
the default value specified for OPEN."
  (once-only (direction element-type if-exists if-does-not-exist external-format)
    `(with-open-stream
         (,stream (apply #'open ,filespec
                         (append
                          (when ,direction
                            (list :direction ,direction))
                          (when ,element-type
                            (list :element-type ,element-type))
                          (when ,if-exists
                            (list :if-exists ,if-exists))
                          (when ,if-does-not-exist
                            (list :if-does-not-exist ,if-does-not-exist))
                          (when ,external-format
                            (list :external-format ,external-format)))))
       ,@body)))

(defmacro with-input-from-file ((stream-name file-name &rest args
                                             &key (direction nil direction-p)
                                             &allow-other-keys)
                                &body body)
  "Evaluate BODY with STREAM-NAME to an input stream on the file
FILE-NAME. ARGS is sent as is to the call to OPEN except EXTERNAL-FORMAT,
which is only sent to WITH-OPEN-FILE when it's not NIL."
  (declare (ignore direction))
  (when direction-p
    (error "Can't specifiy :DIRECTION for WITH-INPUT-FROM-FILE."))
  `(with-open-file* (,stream-name ,file-name :direction :input ,@args)
     ,@body))

(defmacro with-output-to-file ((stream-name file-name &rest args
                                            &key (direction nil direction-p)
                                            &allow-other-keys)
			       &body body)
  "Evaluate BODY with STREAM-NAME to an output stream on the file
FILE-NAME. ARGS is sent as is to the call to OPEN except EXTERNAL-FORMAT,
which is only sent to WITH-OPEN-FILE when it's not NIL."
  (declare (ignore direction))
  (when direction-p
    (error "Can't specifiy :DIRECTION for WITH-OUTPUT-TO-FILE."))
  `(with-open-file* (,stream-name ,file-name :direction :output ,@args)
     ,@body))

(defun read-file-into-string (pathname &key (buffer-size 4096) external-format)
  "Return the contents of the file denoted by PATHNAME as a fresh string.

The EXTERNAL-FORMAT parameter will be passed directly to WITH-OPEN-FILE
unless it's NIL, which means the system default."
  (with-input-from-file
      (file-stream pathname :external-format external-format)
    (let ((*print-pretty* nil))
      (with-output-to-string (datum)
        (let ((buffer (make-array buffer-size :element-type 'character)))
	  (loop
	     :for bytes-read = (read-sequence buffer file-stream)
	     :do (write-sequence buffer datum :start 0 :end bytes-read)
	     :while (= bytes-read buffer-size)))))))

(defun write-string-into-file (string pathname &key (if-exists :error)
                                                    if-does-not-exist
                                                    external-format)
  "Write STRING to PATHNAME.

The EXTERNAL-FORMAT parameter will be passed directly to WITH-OPEN-FILE
unless it's NIL, which means the system default."
  (with-output-to-file (file-stream pathname :if-exists if-exists
                                    :if-does-not-exist if-does-not-exist
                                    :external-format external-format)
    (write-sequence string file-stream)))

(defun read-file-into-byte-vector (pathname)
  "Read PATHNAME into a freshly allocated (unsigned-byte 8) vector."
  (with-input-from-file (stream pathname :element-type '(unsigned-byte 8))
    (let ((length (file-length stream)))
      (assert length)
      (let ((result (make-array length :element-type '(unsigned-byte 8))))
        (read-sequence result stream)
        result))))

(defun write-byte-vector-into-file (bytes pathname &key (if-exists :error)
                                                       if-does-not-exist)
  "Write BYTES to PATHNAME."
  (check-type bytes (vector (unsigned-byte 8)))
  (with-output-to-file (stream pathname :if-exists if-exists
                               :if-does-not-exist if-does-not-exist
                               :element-type '(unsigned-byte 8))
    (write-sequence bytes stream)))

(defun copy-file (from to &key (if-to-exists :supersede)
			       (element-type '(unsigned-byte 8)) finish-output)
  (with-input-from-file (input from :element-type element-type)
    (with-output-to-file (output to :element-type element-type
				    :if-exists if-to-exists)
      (copy-stream input output
                   :element-type element-type
                   :finish-output finish-output))))

(defun copy-stream (input output &key (element-type (stream-element-type input))
                    (buffer-size 4096)
                    (buffer (make-array buffer-size :element-type element-type))
                    finish-output)
  "Reads data from INPUT and writes it to OUTPUT. Both INPUT and OUTPUT must
be streams, they will be passed to READ-SEQUENCE and WRITE-SEQUENCE and must have
compatible element-types."
  (let ((bytes-written 0))
    (loop
      :for bytes-read = (read-sequence buffer input)
      :until (zerop bytes-read)
      :do (progn
            (write-sequence buffer output :end bytes-read)
            (incf bytes-written bytes-read)))
    (when finish-output
      (finish-output output))
    bytes-written))
