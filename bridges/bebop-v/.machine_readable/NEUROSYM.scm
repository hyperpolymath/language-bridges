;; SPDX-License-Identifier: PMPL-1.0-or-later
;; NEUROSYM.scm - Neurosymbolic integration config for bebop-v-ffi

(define neurosym-config
  `((version . "1.0.0")
    (symbolic-layer
      ((type . "scheme")
       (reasoning . "deductive")
       (verification . "formal")))
    (neural-layer
      ((embeddings . false)
       (fine-tuning . false)))
    (integration . ())))
