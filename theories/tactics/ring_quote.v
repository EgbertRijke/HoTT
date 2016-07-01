Require Import HoTT.Basics HoTT.Types.Bool.
Require Import HoTTClasses.theory.rings
  HoTTClasses.interfaces.abstract_algebra
  HoTTClasses.implementations.list.

Import ListNotations.

Module Quoting.

Inductive Expr (V:Type0) :=
  | Var (v : V)
  | Zero
  | One
  | Plus (a b : Expr V)
  | Mult (a b : Expr V)
.

Arguments Var [V] v.
Arguments Zero [V].
Arguments One [V].
Arguments Plus [V] a b.
Arguments Mult [V] a b.

Section contents.
Universe U.
Context (R:Type@{U}) `{SemiRing R}.

Notation Vars V := (V -> R).

Fixpoint eval {V:Type0} (vs : Vars V) (e : Expr V) : R :=
  match e with
  | Var v => vs v
  | Zero => 0
  | One => 1
  | Plus a b => eval vs a + eval vs b
  | Mult a b => eval vs a * eval vs b
  end.

Lemma eval_ext {V:Type0} (vs vs' : Vars V) :
  pointwise_paths@{Set U} vs vs' ->
  pointwise_paths@{Set U} (eval vs) (eval vs').
Proof.
intros E e;induction e;simpl;auto;apply ap2;auto.
Qed.

Definition noVars : Vars Empty.
Proof. intros []. Defined.

Definition singleton x : Vars Unit := fun _ => x.

Definition merge {A B:Type0 } (va:Vars A) (vb:Vars B) : Vars (sum@{Set Set} A B)
  := fun i => match i with inl i => va i | inr i => vb i end.

Section Lookup.

  Class Lookup {A:Type0 } (x: R) (f: Vars A)
    := { lookup: A; lookup_correct: f lookup = x }.

  Global Arguments lookup {A} x f {_}.

  Context (x:R) {A B:Type0 } (va : Vars A) (vb : Vars B).

  Global Instance lookup_l `{!Lookup x va} : Lookup x (merge va vb).
  Proof.
  exists (inl (lookup x va)). apply lookup_correct.
  Defined.

  Global Instance lookup_r `{!Lookup x vb} : Lookup x (merge va vb).
  Proof.
  exists (inr (lookup x vb)). apply lookup_correct.
  Defined.

  Global Instance lookup_single : Lookup x (singleton x).
  Proof.
  exists tt. reflexivity.
  Defined.

End Lookup.

Fixpoint expr_map {V W:Type0 } (f : V -> W) (e : Expr V) : Expr W :=
  match e with
  | Var v => Var (f v)
  | Zero => Zero
  | One => One
  | Plus a b => Plus (expr_map f a) (expr_map f b)
  | Mult a b => Mult (expr_map f a) (expr_map f b)
  end.

Lemma eval_map {V W:Type0 } (f : V -> W) v e
  : eval v (expr_map f e) = eval (compose@{Set Set U} v f) e.
Proof.
induction e;simpl;try reflexivity;apply ap2;auto.
Qed.

Section Quote.

  Class Quote {V:Type0 } (l: Vars V) (n: R) {V':Type0 } (r: Vars V') :=
    { quote : Expr (V + V')
    ; eval_quote : @eval (V+V') (merge l r) quote = n }.

  Global Arguments quote {V l} n {V' r _}.
  Global Arguments eval_quote {V l} n {V' r _}.

  Definition sum_assoc {A B C}: (A+B)+C → A+(B+C).
  Proof.
  intros [[?|?]|?];auto.
  Defined.

  Definition sum_aux {A B C}: (A+B) → A+(B+C).
  Proof.
  intros [?|?];auto.
  Defined.

  Global Instance quote_zero (V:Type0) (v: Vars V): Quote v 0 noVars.
  Proof.
  exists Zero.
  reflexivity.
  Defined.

  Global Instance quote_one (V:Type0) (v: Vars V): Quote v 1 noVars.
  Proof.
  exists One.
  reflexivity.
  Defined.

  Lemma quote_plus_ok (V:Type0) (v: Vars V) n
    (V':Type0) (v': Vars V') m (V'':Type0) (v'': Vars V'')
    `{!Quote v n v'} `{!Quote (merge v v') m v''}
    : eval (merge v (merge v' v''))
      (Plus (expr_map sum_aux (quote n)) (expr_map sum_assoc (quote m))) = 
      n + m.
  Proof.
  simpl.
  rewrite <-(eval_quote n), <-(eval_quote m),
    2!eval_map.
  apply ap2;apply eval_ext.
  - intros [?|?];reflexivity.
  - intros [[?|?]|?];reflexivity.
  Qed.

  Global Instance quote_plus (V:Type0) (v: Vars V) n
  (V':Type0) (v': Vars V') m (V'':Type0) (v'': Vars V'')
  `{!Quote v n v'} `{!Quote (merge v v') m v''}: Quote v (n + m) (merge v' v'').
  Proof.
  econstructor. apply quote_plus_ok.
  Defined.

  Lemma quote_mult_ok (V:Type0) (v: Vars V) n
    (V':Type0) (v': Vars V') m (V'':Type0) (v'': Vars V'')
    `{!Quote v n v'} `{!Quote (merge v v') m v''}
    : eval (merge v (merge v' v''))
      (Mult (expr_map sum_aux (quote n)) (expr_map sum_assoc (quote m))) = 
      n * m.
  Proof.
  simpl.
  rewrite <-(eval_quote n), <-(eval_quote m),
    2!eval_map.
  apply ap2;apply eval_ext.
  - intros [?|?];reflexivity.
  - intros [[?|?]|?];reflexivity.
  Qed.

  Global Instance quote_mult (V:Type0) (v: Vars V) n
    (V':Type0) (v': Vars V') m (V'':Type0) (v'': Vars V'')
    `{!Quote v n v'} `{!Quote (merge v v') m v''}
    : Quote v (n * m) (merge v' v'').
  Proof.
  econstructor. apply quote_mult_ok.
  Defined.

  Global Instance quote_old_var (V:Type0) (v: Vars V) x {i: Lookup x v}
    : Quote v x noVars | 8.
  Proof.
  exists (Var (inl (lookup x v))).
  apply lookup_correct.
  Defined.

  Global Instance quote_new_var (V:Type0) (v: Vars V) x
    : Quote v x (singleton x) | 9.
  Proof.
  exists (Var (inr tt)).
  reflexivity.
  Defined.

End Quote.

Definition quote': ∀ x {V':Type0 } {v: Vars V'} {d: Quote noVars x v}, Expr _
  := @quote _ _.

Definition eval_quote': ∀ x {V':Type0} {v: Vars V'} {d: Quote noVars x v},
  eval (merge noVars v) (quote x) = x
  := @eval_quote _ _.

Class EqQuote {V:Type0 } (l: Vars V) (n m: R) {V':Type0 } (r: Vars V') :=
    { eqquote_l : Expr V
    ; eqquote_r : Expr (V + V')
    ; eval_eqquote : eval (merge l r) (expr_map inl eqquote_l)
                   = eval (merge l r) eqquote_r -> n = m }.

Lemma eq_quote_ok (V:Type0) (v: Vars V) n
  (V':Type0) (v': Vars V') m (V'':Type0) (v'': Vars V'')
  `{!Quote v n v'} `{!Quote (merge v v') m v''}
  : eval (merge v (merge v' v'')) (expr_map sum_aux (quote n))
  = eval (merge v (merge v' v'')) (expr_map sum_assoc (quote m))
  -> n = m.
Proof.
intros E.
rewrite <-(eval_quote n), <-(eval_quote m).
path_via (eval (merge v (merge v' v'')) (expr_map sum_aux (quote n)));
[|path_via (eval (merge v (merge v' v'')) (expr_map sum_assoc (quote m)))].
- rewrite eval_map. apply eval_ext.
  intros [?|?];reflexivity.
- rewrite eval_map. apply eval_ext.
  intros [[?|?]|?];reflexivity.
Qed.

Global Instance eq_quote (V:Type0) (v: Vars V) n
  (V':Type0) (v': Vars V') m (V'':Type0) (v'': Vars V'')
  `{!Quote v n v'} `{!Quote (merge v v') m v''}
  : EqQuote (merge v v') n m v''.
Proof.
econstructor.
intros E.
apply (@eq_quote_ok _ _ _ _ _ _ _ _ Quote0 Quote1).
etransitivity;[etransitivity;[|exact E]|].
- rewrite 2!eval_map. apply eval_ext. intros [?|?];reflexivity.
- rewrite (eval_map sum_assoc).
  apply eval_ext. intros [[?|?]|?];reflexivity.
Defined.

Definition sum_forget {A B} : Empty + A -> A + B.
Proof.
intros [[]|?];auto.
Defined.

Lemma quote_equality {V:Type0} {v: Vars V}
  {V':Type0} {v': Vars V'} (l r: R)
  `{!Quote noVars l v} `{!Quote v r v'}
  : let heap := (merge v v') in
  eval heap (expr_map sum_forget (quote l)) = eval heap (quote r) → l = r.
Proof.
intros ? E.
rewrite <-(eval_quote l),<-(eval_quote r).
path_via (eval heap (expr_map sum_forget (quote l))).
rewrite eval_map. apply eval_ext.
intros [[]|?]. reflexivity.
Qed.

End contents.

End Quoting.