## Rationale:

(In my mind) the product description of H is "a realistic depiction of
a mechanical watch on a small portable display like an iPhone."  This
is interesting to me because it's a way of actually owning and looking
at a mechanical contrivance that is very interesting but would not be
something I would actually own because of cost.  Something that's
computer generated isn't interesting at all in this context; I don't
want to model a watch with a digital display.  At one time I suggested
modeling digital watches only because at that time I was thinking we
could model actual watches that exist in the real world, and I thought
that might be interesting too (I still do, although I would never do
such a copycat watch for sale now).  My interest in "mechanical"
things here is really about gears and levers and cams.  I have no
interest in polarization in this context any more than I have an
interest in LCDs in this context.

My presumption is that other people will feel the way I do.  So I
presume that if a watch appears to be impossible at first glance, it
will fail to be interesting in the same way to those people.  I draw
the distinction between things that appear to violate the laws of
physics from things "below the face" that seem too complicated to
implement with gears and levers in the space available; the former
don't fit the model, but for the latter I can imagine some complex
works going on that I haven't figured out (more on this below).

I further presume that if someone is interested in our application,
that they are at least in the same ballpark as my position.  Someone
simply interested in the best possible time or astronomy display
probably wants a totally different application; the restrictions that
we 1) fit into a watch face circle and 2) display things without
digital displays are alone too constraining not to adversely affect
the usefulness of the application.  But, like real-world watch
designers, we can design things that fit into those constraints with
pretty good UI; that's our challenge as I see it.

## Position:


1. The visible parts of the watch must be implementable with gears and
   levers and other moving mechanical parts.  Changes in appearance must
   be a result of visible changes in object positions; displays can't
   change when an object doesn't move.

2. A corollary to 1) is that things in windows must be implementable
   with physical things that slide into position, without running into
   other objects [our current H implementation with holes in images and
   views that must stack in a given physical order more or less
   guarantees we obey this model.  But this principle would come into
   play if we decided to work around it in some way].

3. Visible objects should not jump from one position to another on
   screen.  The motion must appear to be physically possible on the
   surface.

4. Operations which are impossible in a real watch, but that could be
   obtained by occasional manual intervention, are OK.  For example, a
   real watch wouldn't keep good time left by itself, but could be set
   periodically to the required accuracy.  Similarly, a watch wouldn't
   reset its sunrise dial to the correct time when it moves to a
   different location, but (in my mind at least) that could be obtained
   by turning screws on the back to set the longitude and latitude.
   We're just saving you a step; the actual operation of the watch once
   those manual steps have been followed is identical to a real
   mechanical.

5. Motions which are impossible to implement logically, if they exist,
   are in a gray area.  But I'm not sure there are any such operations.
   One could imagine a Turing-equivalent Analytical Engine compressed to
   the size of a watch and not violate any of the rules given so far.
   The only things such a watch wouldn't have would be time and location
   from an external source, and 4) above deals with those directly.

6. "Optical illusions" on the face, which appear to be impossible but
   for which an explanation could be given, are in a similar gray area.
   But my default position would be to disallow such things, because
   what's really important is what it looks like to the user, not whether
   we can justify it to ourselves.  I would prefer not to resort to
   explaining why it's ok in the manual somewhere.  But this is a gray
   area because if something is really simple to implement mechanically I
   think it would be OK.

7. Any mode [like x-ray mode] that shows the internal workings of the
   watch must not violate any of these rules either.  Note that this is a
   severe constraint; once you show the workings of the watch, then there
   is no longer anything "underneath the face".  It is no longer possible
   to imagine a miniature analytic engine inside the watch if you look
   inside and don't find one.
