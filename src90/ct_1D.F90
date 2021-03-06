!=======================================================================
!
!    \\\\\\\\\\      B E G I N   S U B R O U T I N E      //////////
!    //////////                  C T _ 1 D                \\\\\\\\\\
!
!                            Developed by
!                Laboratory of Computational Astrophysics
!               University of California at San Diego
!
!=======================================================================
!
       subroutine ct_1D
!
!    dac:zeus3d.ct <-------- updates B-field using constrained transport
!    from jms:zeus2d.ct                                    october, 1989
!
!    written by: David Clarke
!    modified 1: May, 1990 by David Clarke; reworked to call the new
!                interpolation routines which need only be called once.
!    modified 2: August, 1990 by David Clarke; moved magnetic fields to
!                the face-centres (cospatial with the velocities).
!                Implemented a method of characteristics for evaluating
!                the emf's.  The transverse Lorentz accelerations are
!                now applied to the velocities during this step.
!    modified 3: November, 1990 by David Clarke; resurrected non-MoC
!                algorithm for evaluating emfs.  Added EDITOR alias MOC
!                which needs to be defined if MoC is to be used.
!    modified 4: June, 1992 by David Clarke; reworked singularity
!                formalism.
!    modified 5: December, 1992 by David Clarke (as suggested by John
!                Hawley); split velocity update from emf computation.
!                Velocities are now Lorentz-accelerated with *old*
!                magnetic field values. emf's are then estimated with
!                Lorentz-updated velocities.
!    modified 6: 3 March 1998, by Mordecai-Mark Mac Low; translated 
!                into ZEUS-MP form.
!
!    modified 7: created "ct_1D" clone which assumes symmetry about the
!                J and K axes, after ZEUS3D. (J. Hayes; October 2005)
!
!    modified 8: John Hayes, May 15, 2006; changed the call to LORENTZ_D
!                so that old velocities are passed in via a locally
!                defined scratch array rather than through the v[123] field
!                arrays; the latter now receive updated values only. This
!                change, combined with additional edits in LORENTZ_D
!                itself, correct an old error in which two variables
!                were assigned the same space in memory.
!
!    modified 9: extended ranges of [i,j,k] DO loops copying v[1,2,3]
!                values into u[1,2,3] arrays.  Avoids passing uninitialized
!                u[1,2,3] values into bvalv[1,2,3] -- JHayes, 09/20/2006
!
!  PURPOSE:  This routine transports the three components of the
!  magnetic field using a variation of the non-relativistic Constrained
!  Transport scheme (CT), developed by Chuck Evans and John Hawley (Ap.
!  J., 342, 700).  In this implementation, the magnetic field components
!  are face-centred, cospatial with the velocities and are updated using
!  edge-centred emf's which are cospatial with the current densities.
!
!  The emf's are evaluated by HSMOC in which the velocities and
!  magnetic field components required to compute the emf's are estimated
!  using the Method of Characteristics (MoC) algorithm developed by Jim
!  Stone et al. for 2-D.  For self-consistency, the transverse Lorentz
!  accelerations have been removed from STV* and are applied to the
!  velocities in LORENTZ using the pre-updated magnetic fields.  By
!  experimentation, it has been determined that performing the Lorentz
!  update after the magnetic field update is unstable.
!
!  LOCAL VARIABLES:
!    emf1      emf along the 2-3 edges of the grid (= v2*b3 - v3*b2)
!    emf2      emf along the 3-1 edges of the grid (= v3*b1 - v1*b3)
!    emf3      emf along the 1-2 edges of the grid (= v1*b2 - v2*b1)
!
! BOUNDARY VALUES USED:
!
!    var    ii    oi    ij    oj    ik    ok
!    ----  ----  ----  ----  ----  ----  ----
!    emf1  is-2  ie+2  js-2  je+3  ks-2  ke+3
!    emf2  is-2  ie+3  js-2  je+2  ks-2  ke+3
!    emf3  is-2  ie+3  js-2  je+3  ks-2  ke+2
!
!  EXTERNALS:
!    LORENTZ_D, HSMOC 
!
!-----------------------------------------------------------------------
!
      use config
      use param
      use grid
      use field
      use root
      use scratch
#ifdef MPI_USED
      use mpiyes
#else
      use mpino
#endif
      use mpipar
!
      implicit NONE
!
      integer  :: i, ip1, j, jp1, k, kp1
      integer  :: jone, kone, km1   !asif
!
      real(rl) :: qty1(ijkn), qty1ni(ijkn), qty2(ijkn), &
                  qty2ni  (ijkn)
!
      real(rl) :: emf1(in,jn,kn), emf2(in,jn,kn), &
                  emf3(in,jn,kn)
!
      real(rl) :: u1(in,jn,kn), u2(in,jn,kn), u3(in,jn,kn)
!
      kone = 0
      jone = 0
      if(xforce) then
!
!-----------------------------------------------------------------------
!-------------------------> Update velocities <-------------------------
!-----------------------------------------------------------------------
!
!      Compute the transverse Lorentz forces and accelerate the
!  velocities.
!
       do k = 1, kn
        do j = 1, jn
         do i = 1, in
          u1(i,j,k) = v1(i,j,k)
          u2(i,j,k) = v2(i,j,k)
          u3(i,j,k) = v3(i,j,k)
         enddo
        enddo
       enddo
       call lorentz_d (u1, u2, u3, v1, v2, v3)
      endif ! xforce
!
!-----------------------------------------------------------------------
!-------------------------------> emfs <--------------------------------
!-----------------------------------------------------------------------
!
!  update all the boundary values of v before going into hsmoc to
!  compute the emfs.  Boy could this ever benefit from some
!  overlapping! think about this... (M-MML/MLN 25.3.98)
       nreq=0
       nsub = nsub + 1
       call bvalv1(3,3,0,0,0,0,v1)
       call bvalv2(3,3,0,0,0,0,v2)
       call bvalv3(3,3,0,0,0,0,v3)
#ifdef MPI_USED
       if (nreq .ne. 0) call MPI_WAITALL ( nreq, req, stat, ierr )
#endif
      if(ldimen .gt. 1) then
       nreq=0
       nsub = nsub + 1
       call bvalv1(0,0,3,3,0,0,v1)
       call bvalv2(0,0,3,3,0,0,v2)
       call bvalv3(0,0,3,3,0,0,v3)
#ifdef MPI_USED
       if (nreq .ne. 0) call MPI_WAITALL ( nreq, req, stat, ierr )
#endif
      endif ! ldimen
!
       if(ldimen.eq.3) then   !asif
       nreq=0
       nsub = nsub + 1
       call bvalv1(0,0,0,0,3,3,v1)
       call bvalv2(0,0,0,0,3,3,v2)
       call bvalv3(0,0,0,0,3,3,v3)
#ifdef MPI_USED
       if (nreq .ne. 0) call MPI_WAITALL ( nreq, req, stat, ierr )
#endif
       endif   !asif, ldimen
!
       call hsmoc_1d   ( emf1, emf2, emf3 )
!
!-----------------------------------------------------------------------
!
!      The emf's are finished.  Update b1, b2, and b3 using the emf's.
!  Since the same emf's are used throughout the grid, div(b) will be
!  conserved numerically to within truncation error.
!
!      Coordinate-imposed boundary conditions (e.g., reflecting at x2a=0
!  in ZRP, periodic at x3a=2*pi in RTP and ZRP) are communicated to the
!  magnetic field by the emfs.  Both the old and new zone face areas are
!  used to account for grid compression.
!
!-----------------------------------------------------------------------
!-----------------------------> Update b1 <-----------------------------
!-----------------------------------------------------------------------
!
       do 10 i=is,ie+1
         qty1  (i) = g2a   (i) * g31a  (i)
        if(xvgrid) then
         qty1ni(i) = g2ani (i) * g31ani(i)
        else
         qty1ni(i) = g2ai (i) * g31ai(i)
        endif
10     continue
       do 20 j=js-2,je+2
         qty2  (j) = g32b  (j) * dx2a  (j)
        if(xvgrid) then
         qty2ni(j) = g32bni(j) * dx2ani(j)
        else
         qty2ni(j) = g32bi(j) * dx2ai(j)
        endif
20     continue
      k  = ks
      j  = js
      i  = is
      kp1 = k + kone
       jp1 = j + jone
        do 30 i=is,ie+1
         if(xvgrid) then
          b1(i,j,k) = ( b1(i,j,k) * qty1(i) * qty2(j) * dx3a(k) &
                    + dt * ( emf3(i,jp1,k  ) - emf3(i,j,k) &
                           - emf2(i,j  ,kp1) + emf2(i,j,k) ) ) &
                    * qty1ni(i) * qty2ni(j) * dx3ani(k)
         else
          b1(i,j,k) = ( b1(i,j,k) * qty1(i) * qty2(j) * dx3a(k) &
                    + dt * ( emf3(i,jp1,k  ) - emf3(i,j,k) &
                           - emf2(i,j  ,kp1) + emf2(i,j,k) ) ) &
                    * qty1ni(i) * qty2ni(j) * dx3ai(k)
         endif
30      continue
!
!-----------------------------------------------------------------------
!-----------------------------> Update b2 <-----------------------------
!-----------------------------------------------------------------------
!
       do 60 i=is-2,ie+2
         qty1  (i) = g31b  (i) * dx1a  (i)
        if(xvgrid) then
         qty1ni(i) = g31bni(i) * dx1ani(i)
        else
         qty1ni(i) = g31bi(i) * dx1ai(i)
        endif
60     continue
!
       k = ks
       j = js
       i = is
       kp1 = k + kone
        do 80 i=is-2,ie+2
         if(xvgrid) then
          b2(i,j,k) = ( b2(i,j,k) * qty1(i) * g32a(j) * dx3a(k) &
                    + dt * ( emf1(i  ,j,kp1) - emf1(i,j,k) &
                           - emf3(i+1,j,k  ) + emf3(i,j,k) ) ) &
                    * qty1ni(i) * g32ani(j) * dx3ani(k)
         else
          b2(i,j,k) = ( b2(i,j,k) * qty1(i) * g32a(j) * dx3a(k) &
                    + dt * ( emf1(i  ,j,kp1) - emf1(i,j,k) &
                           - emf3(i+1,j,k  ) + emf3(i,j,k) ) ) &
                    * qty1ni(i) * g32ai(j) * dx3ai(k)
         endif
80      continue
!
!-----------------------------------------------------------------------
!-----------------------------> Update b3 <-----------------------------
!-----------------------------------------------------------------------
!
       do 110 i=is-2,ie+2
         qty1  (i) = g2b   (i) * dx1a  (i)
        if(xvgrid) then
         qty1ni(i) = g2bni (i) * dx1ani(i)
        else
         qty1ni(i) = g2bi (i) * dx1ai(i)
        endif
110    continue
!
       k = ks
       j = js
       i = is
       jp1 = j + jone
        do 130 i=is-2,ie+2
         if(xvgrid) then
          b3(i,j,k) = ( b3(i,j,k) * qty1(i) * dx2a(j) &
                    + dt * ( emf2(i+1,j  ,k) - emf2(i,j,k) &
                           - emf1(i  ,jp1,k) + emf1(i,j,k) ) ) &
                    * qty1ni(i) * dx2ani(j)
         else
          b3(i,j,k) = ( b3(i,j,k) * qty1(i) * dx2a(j) &
                    + dt * ( emf2(i+1,j  ,k) - emf2(i,j,k) &
                           - emf1(i  ,jp1,k) + emf1(i,j,k) ) ) &
                    * qty1ni(i) * dx2ai(j)
         endif
130     continue
!
       return
       end
!
!=======================================================================
!
!    \\\\\\\\\\        E N D   S U B R O U T I N E        //////////
!    //////////                  C T _ 1 D                \\\\\\\\\\
!
!=======================================================================
!
