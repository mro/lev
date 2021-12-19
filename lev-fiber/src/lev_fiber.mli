open Stdune

module Timer : sig
  val sleepf : float -> unit Fiber.t
  (** [sleep f] wait for [f] seconds  *)

  module Wheel : sig
    type t
    (** wheel to handle many constant timeouts efficiently *)

    val create : delay:float -> t Fiber.t
    (** [create ~delay] will create a wheel that times out every task in [delay] *)

    type task
    (** a task scheduled by the timer wheel *)

    val reset : task -> unit

    val task : t -> task Fiber.t
    (** create a new task *)

    val await : task -> [ `Ok | `Cancelled ] Fiber.t
    (** wait for delay seconds *)

    val cancel : task -> unit Fiber.t
    (** cancel waiting *)

    val run : t -> unit Fiber.t
    (** run the wheel forever *)

    val stop : t -> unit Fiber.t
    (** [stop t] stop running the wheel and cancel everything.
        it's an error to call [task t] after this. *)
  end
end

val waitpid : pid:int -> Unix.process_status Fiber.t

module Thread : sig
  type t

  val create : unit -> t Fiber.t

  type 'a task

  val task : t -> f:(unit -> 'a) -> 'a task Fiber.t
  val cancel : 'a task -> unit Fiber.t

  val await :
    'a task ->
    ('a, [ `Exn of Exn_with_backtrace.t | `Cancelled ]) result Fiber.t

  val close : t -> unit
end

module Io : sig
  type input = Input
  type output = Output
  type 'a mode = Input : input mode | Output : output mode
  type 'a t

  val create :
    Unix.file_descr -> [ `Blocking | `Non_blocking ] -> 'a mode -> 'a t Fiber.t

  val create_rw :
    Unix.file_descr ->
    [ `Blocking | `Non_blocking ] ->
    (input t * output t) Fiber.t

  module Slice : sig
    type t = { pos : int; len : int }
  end

  val write : output t -> Faraday.t -> [ `Yield | `Close ] Fiber.t

  module Reader : sig
    type t

    val available : t -> [ `Ok of int | `Eof ]
    val buffer : t -> Bytes.t * Slice.t
    val consume : t -> len:int -> unit
    val refill : ?size:int -> t -> unit Fiber.t
  end

  val with_read : input t -> f:(Reader.t -> 'a Fiber.t) -> 'a Fiber.t
  val close : 'a t -> unit
  val pipe : ?cloexec:bool -> unit -> (input t * output t) Fiber.t
end

module Socket : sig
  module Server : sig
    type t

    val create : Unix.file_descr -> Unix.sockaddr -> backlog:int -> t Fiber.t
    val close : t -> unit Fiber.t

    val serve :
      t -> f:(Unix.file_descr -> Unix.sockaddr -> unit Fiber.t) -> unit Fiber.t
  end

  val connect : Unix.file_descr -> Unix.sockaddr -> unit Fiber.t
end

val run : Lev.Loop.t -> f:(unit -> 'a Fiber.t) -> 'a
